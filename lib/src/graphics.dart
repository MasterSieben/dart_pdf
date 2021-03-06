/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General 
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General  License for more details.
 *
 * You should have received a copy of the GNU Lesser General 
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

part of pdf;

enum PDFLineCap { JOIN_MITER, JOIN_ROUND, JOIN_BEVEL }

class PDFGraphics {
  /// Graphic context number
  var _context = 0;

  final PDFPage page;

  final PDFStream buf;

  PDFGraphics(this.page, this.buf);

  PDFFont get defaultFont {
    if (page.pdfDocument.fonts.length == 0) {
      new PDFFont(page.pdfDocument);
    }

    return page.pdfDocument.fonts.elementAt(0);
  }

  void fillPath() {
    buf.putString("f\n");
  }

  void strokePath() {
    buf.putString("S\n");
  }

  void closePath() {
    buf.putString("s\n");
  }

  void clipPath() {
    buf.putString("W n\n");
  }

  /// <p>This releases any resources used by this Graphics object. You must use
  /// this method once finished with it. Leaving it open will leave the PDF
  /// stream in an inconsistent state, and will produce errors.</p>
  /// <p>
  /// <p>If this was created with Graphics.create() then the parent instance
  /// can be used again. If not, then this closes the graphics operations for
  /// this page when used with PDFJob.</p>
  /// <p>
  /// <p>When using PDFPage, you can create another fresh Graphics instance,
  /// which will draw over this one.</p>
  void restoreContext() {
    if (_context > 0) {
      // restore graphics context
      buf.putString("Q\n");
      _context--;
    }
  }

  void saveContext() {
    // save graphics context
    buf.putString("q\n");
    _context++;
  }

  /// <p>Draws an image onto the page.</p>
  /// <p>
  /// <p>This method is implemented with ASCIIbase85 encoding and the
  /// zip stream deflater.  It results in a stream that is anywhere
  /// from 3 to 10 times as big as the image.  This obviously needs some
  /// improvement, but it works well for small images</p>
  ///
  /// @param img The java.awt.Image
  /// @param x   coordinate on page
  /// @param y   coordinate on page
  /// @param w   Width on page
  /// @param h   height on page
  /// @param bgcolor Background colour
  /// @return true if drawn
  void drawImage(PDFImage img, double x, double y, [double w, double h]) {
    if (w == null) w = img.width.toDouble();
    if (h == null) h = img.height.toDouble() * w / img.width.toDouble();

    // The image needs to be registered in the page resources
    page.xObjects[img.name] = img;

    // q w 0 0 h x y cm % the coordinate matrix
    buf.putString("q $w 0 0 $h $x $y cm ${img.name} Do Q\n");
  }

  /// Draws a line between two coordinates.
  /// <p>
  /// If the first coordinate is the same as the last one drawn
  /// (i.e. a previous drawLine, moveto, etc) it is ignored.
  ///
  /// @param x1 coordinate
  /// @param y1 coordinate
  /// @param x2 coordinate
  /// @param y2 coordinate
  void drawLine(double x1, double y1, double x2, double y2) {
    moveTo(x1, y1);
    lineTo(x2, y2);
  }

  /// Draws a polygon, linking the first and last coordinates.
  ///
  /// @param xp Array of x coordinates
  /// @param yp Array of y coordinates
  /// @param np number of points in polygon
  void drawPolygon(Polygon p) {
    _polygon(p.points);
  }

  void drawEllipse(double x, double y, double r1, double r2) {
    // The best 4-spline magic number
    double m4 = 0.551784;

    // Starting point
    moveTo(x, y - r2);

    buf.putString("${x + m4 * r1} ${y - r2} ${x + r1} ${y - m4 * r2} ${x + r1} $y c\n");
    buf.putString("${x + r1} ${y + m4 * r2} ${x + m4 * r1} ${y + r2} $x ${y + r2} c\n");
    buf.putString("${x - m4 * r1} ${y + r2} ${x - r1} ${y + m4 * r2} ${x - r1} $y c\n");
    buf.putString("${x - r1} ${y - m4 * r2} ${x - m4 * r1} ${y - r2} $x ${y - r2} c\n");
  }

  /// We override Graphics.drawRect as it doesn't join the 4 lines.
  /// Also, PDF provides us with a Rectangle operator, so we will use that.
  ///
  /// @param x coordinate
  /// @param y coordinate
  /// @param w width
  /// @param h height
  void drawRect(
    double x,
    double y,
    double w,
    double h,
  ) {
    buf.putString("$x $y $w $h re\n");
  }

  /// This draws a string.
  ///
  /// @param x coordinate
  /// @param y coordinate
  /// @oaran s String to draw
  void drawString(PDFFont font, size, String s, double x, double y) {
    if (!page.fonts.containsKey(font.name)) {
      page.fonts[font.name] = font;
    }

    buf.putString("BT $x $y Td ${font.name} $size Tf ");
    buf.putText(s);
    buf.putString(" Tj ET\n");
  }

  /// Sets the color for drawing
  ///
  /// @param c Color to use
  void setColor(PDFColor color) {
    buf.putString("${color.r} ${color.g} ${color.b} rg ${color.r} ${color.g} ${color.b} RG\n");
  }

  /// Set the transformation Matrix
  void setTransform(Matrix4 t) {
    var s = t.storage;
    buf.putString("${s[0]} ${s[1]} ${s[4]} ${s[5]} ${s[12]} ${s[13]} cm\n");
  }

  /// This adds a line segment to the current path
  ///
  /// @param x coordinate
  /// @param y coordinate
  void lineTo(double x, double y) {
    buf.putString("$x $y l\n");
  }

  /// This moves the current drawing point.
  ///
  /// @param x coordinate
  /// @param y coordinate
  void moveTo(double x, double y) {
    buf.putString("$x $y m\n");
  }

  void drawShape(String d) {
    var sb = new StringBuffer();

    RegExp exp = new RegExp(r"([MmZzLlHhVvCcSsQqTtAa])|(-[\.0-9]+)|([\.0-9]+)");
    var matches = exp.allMatches(d);
    var action;
    for (var m in matches) {
      var a = m.group(1);
      var b = m.group(0);
      print("$a, $b");
      if (a != null) {
        if (action != null) {
          sb.write("$action ");
        }
        action = a;
      } else {
        sb.write("$b ");
      }
    }
    print(sb);
    buf.putString(sb.toString());
  }

  /// This is used to add a polygon to the current path.
  /// Used by drawPolygon(), drawPolyline() and fillPolygon() etal
  ///
  /// @param p Array of coordinates
  /// @see #drawPolygon
  /// @see #drawPolyline
  /// @see #fillPolygon
  void _polygon(List<PDFPoint> p) {
    // newPath() not needed here as moveto does it ;-)
    moveTo(p[0].w, p[0].h);

    for (int i = 1; i < p.length; i++) lineTo(p[i].w, p[i].h);
  }

  void setLineCap(PDFLineCap cap) {
    buf.putString("${cap.index} J\n");
  }

  void setLineJoin(PDFLineCap join) {
    buf.putString("${join.index} j\n");
  }

  void setLineWidth(double width) {
    buf.putString("$width w\n");
  }

  void setMiterLimit(double limit) {
    buf.putString("$limit M\n");
  }
}
