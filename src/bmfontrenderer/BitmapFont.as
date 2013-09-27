package bmfontrenderer {
import flash.display.BitmapData;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.utils.Dictionary;

/**
 * Represents a bitmapped font which can be drawn to a BitmapData.
 *
 * Uses BMFont data as generated by :
 *  - BMFont (http://www.angelcode.com/products/bmfont/, win32)
 *  - Hiero (http://slick.cokeandcode.com/demos/hiero.jnlp, cross platform)
 *  - Littera (http://kvazars.com/littera/, web)
 *
 * Currently does not support:
 *      - Kerning.
 *      - Channel packing (currently blits all channels).
 *      - Line breaks/text alignment.
 *      - Unicode outside of the Basic Multilingual Plane.
 */
public class BitmapFont {

	private static var glyphMap:Dictionary = new Dictionary();
	private static var sheets:Dictionary = new Dictionary();

	private static var defaultFont:String;

	//---------------------------------
	//
	//---------------------------------

	public static function createText(text:String, fontName:String = null, startX:int = 0, startY:int = 0):BitmapData {
		var retVal:BitmapData;
		if (!fontName) {
			fontName = defaultFont;
		}
		var size:Point = getTextSize(fontName, text);
		if (size.x && size.y) {
			retVal = new BitmapData(startX + size.x, startY + size.y, true, 0xFF);
			drawString(text, retVal, fontName, startX, startY);
		} else {
			retVal = new BitmapData(1, 1, true, 0xFF);
		}
		return retVal;
	}


	/**
	 * Draw a string to a BitmapData.
	 *
	 * @param text String to draw.
	 * @param target BitmapData to draw to.
	 * @param startX X pixel position to start drawing at.
	 * @param startY Y pixel position to start drawing at.
	 *
	 */
	public static function drawString(text:String, target:BitmapData, fontName:String = null, startX:int = 0, startY:int = 0):void {

		if (!fontName) {
			fontName = defaultFont;
		}

		var curX:int = startX;
		var curY:int = startY;

		var sourceRectangle:Rectangle = new Rectangle();
		var destinationPoint:Point = new Point();

		var fontMap:Array = glyphMap[fontName];
		var fontPics:Array = sheets[fontName];

		if (fontMap && fontPics) {

			// Walk the string.
			for (var curCharIdx:int = 0; curCharIdx < text.length; curCharIdx++) {
				// Identify the glyph.
				var curChar:int = text.charCodeAt(curCharIdx);
				var curGlyph:BitmapGlyph = fontMap[curChar];
				var sourceBd:BitmapData = fontPics[curGlyph.page];

				// skip missing glyphs.
				if (!curGlyph || !sourceBd) {
					continue;
				}

				// set draw parameters
				sourceRectangle.x = curGlyph.x;
				sourceRectangle.y = curGlyph.y;
				sourceRectangle.width = curGlyph.width;
				sourceRectangle.height = curGlyph.height;

				destinationPoint.x = curX + curGlyph.xoffset;
				destinationPoint.y = curY + curGlyph.yoffset;

				// Draw the glyph.
				target.copyPixels(sourceBd, sourceRectangle, destinationPoint, null, null, true);

				// Update cursor position
				curX += curGlyph.xadvance;
			}
		}
	}

	public static function getTextSize(fontName:String, text:String):Point {
		var retVal:Point = new Point();

		var fontMap:Array = glyphMap[fontName];
		var fontPics:Array = sheets[fontName];

		if (fontMap && fontPics) {

			// Walk the string.
			for (var curCharIdx:int = 0; curCharIdx < text.length; curCharIdx++) {
				// Identify the glyph.
				var curChar:int = text.charCodeAt(curCharIdx);
				var curGlyph:BitmapGlyph = fontMap[curChar];
				var sourceBd:BitmapData = fontPics[curGlyph.page];

				// skip missing glyphs.
				if (!curGlyph || !sourceBd) {
					continue;
				}

				if (curCharIdx == 0) {
					retVal.x += curGlyph.xoffset;
				}
				if (curCharIdx != text.length - 1) {
					retVal.x += curGlyph.xadvance;
				} else {
					retVal.x += curGlyph.width;
				}

				if (retVal.y < curGlyph.height + curGlyph.yoffset) {
					retVal.y = curGlyph.height + curGlyph.yoffset;
				}
			}
		}
		return retVal;
	}

	//---------------------------------
	// set up
	//---------------------------------

	public static function addFont(fontName:String, fontDesc:String, pagePics:Array, isFlipped:Boolean = false, useAsDefault:Boolean = false):void {
		parseFont(fontName, fontDesc);
		for (var i:int = 0; i < pagePics.length; i++) {
			var pageBD:BitmapData = pagePics[i];
			addSheet(fontName, i, pageBD, isFlipped);
		}

		if (useAsDefault || !defaultFont) {
			defaultFont = fontName;
		}
	}

	/**
	 * Add a bitmap sheet.
	 */
	private static function addSheet(fontName:String, id:int, bits:BitmapData, isFlipped:Boolean = false):void {
		if (!sheets[fontName]) {
			sheets[fontName] = new Array();
		}

		if (sheets[fontName][id] != null) {
			throw new Error("Overwriting sheet!");
		}

		if (isFlipped) {
			sheets[fontName][id] = flipVert(bits);
		} else {
			sheets[fontName][id] = bits;
		}
	}

	/**
	 * Parse a BMFont textual font description.
	 */
	private static function parseFont(fontName:String, fontDesc:String):void {
		var fontLines:Array = fontDesc.split("\n");

		for (var i:int = 0; i < fontLines.length; i++) {
			// Lines can be one of:
			//  info
			//  page
			//  chars
			//  char
			//  common

			var fontLine:Array = (fontLines[i] as String).split(" ");
			var keyWord:String = (fontLine[0] as String).toLowerCase();

			if (keyWord == "char") {
				parseChar(fontName, fontLine);
				continue;
			}

			if (keyWord == "info") {
				// Ignore.
				continue;
			}

			if (keyWord == "page") {
				// Ignore.
				continue;
			}

			if (keyWord == "chars") {
				// Ignore.
				continue;
			}
		}
	}

	/**
	 * Helper function to parse and register a glyph from a BMFont
	 * description..
	 */
	protected static function parseChar(fontName:String, charLine:Array):void {
		var g:BitmapGlyph = new BitmapGlyph();

		if (!glyphMap[fontName]) {
			glyphMap[fontName] = new Array();
		}

		for (var i:int = 1; i < charLine.length; i++) {
			// Parse to key value.
			var charEntry:Array = (charLine[i] as String).split("=");
			if (charEntry.length != 2) {
				continue;
			}

			var charKey:String = charEntry[0];
			var charVal:String = charEntry[1];

			// Assign to glyph.
			if (g.hasOwnProperty(charKey)) {
				g[charKey] = charVal;
			}
		}
		glyphMap[fontName][g.id] = g;
	}


	//---------------------------------
	// utils
	//---------------------------------

	/**
	 * Utility function to return a copy of a BitmapData flipped vertically.
	 */
	public static function flipVert(bd:BitmapData):BitmapData {
		var mat:Matrix = new Matrix();
		mat.d = -1;
		mat.ty = bd.height;

		var flip:BitmapData = new BitmapData(bd.width, bd.height, bd.transparent, 0x0);
		flip.draw(bd, mat);

		return flip;
	}


}
}