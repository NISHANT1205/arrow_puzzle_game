import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
func read(_ path:String)->CGImage {CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath:path) as CFURL,nil)!,0,nil)!}
let args=CommandLine.arguments
let design=read(args[1]), raw=read(args[2])
let w=1080,h=1920
let cutoff=Double(args.count>4 ? args[4] : "455")!
let c=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
c.interpolationQuality = .high
c.draw(design,in:CGRect(x:0,y:0,width:w,height:h))
func topRect(_ x:Double,_ y:Double,_ width:Double,_ height:Double)->CGRect {CGRect(x:x,y:Double(h)-y-height,width:width,height:height)}
// Retain the generated headline artwork. Replace its screenshot area with
// exact simulator pixels, preserving real arrow paths, labels and dialogs.
c.saveGState();c.clip(to:topRect(0,cutoff,1080,1920-cutoff))
let colors=[CGColor(red:0.925,green:0.958,blue:1,alpha:1),CGColor(red:0.88,green:0.936,blue:1,alpha:1)] as CFArray
let g=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:[0,1])!
c.drawLinearGradient(g,start:CGPoint(x:0,y:1920-cutoff),end:CGPoint(x:1080,y:0),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
c.setStrokeColor(CGColor(red:0.50,green:0.70,blue:0.98,alpha:0.28));c.setLineWidth(21);c.setLineCap(.round);c.setLineJoin(.round)
func path(_ points:[(Double,Double)]) {c.beginPath();for (i,p) in points.enumerated(){let pt=CGPoint(x:p.0,y:1920-p.1);if i==0{c.move(to:pt)}else{c.addLine(to:pt)}};c.strokePath()}
path([(-20,640),(84,640),(84,1040),(151,1040)]);path([(122,1012),(151,1040),(122,1068)])
path([(1100,740),(1008,740),(1008,1250),(949,1250)]);path([(978,1222),(949,1250),(978,1278)])
path([(-10,1330),(90,1330),(90,1775)]);path([(62,1747),(90,1775),(118,1747)])
path([(1090,1510),(997,1510),(997,1800)]);path([(969,1772),(997,1800),(1025,1772)])
c.restoreGState()
let cropped=raw.cropping(to:CGRect(x:0,y:186,width:raw.width,height:raw.height-288))!
let panelW=680.0,panelH=panelW*Double(cropped.height)/Double(cropped.width)
let panel=topRect(200,525,panelW,panelH)
let rounded=CGPath(roundedRect:panel,cornerWidth:48,cornerHeight:48,transform:nil)
c.saveGState();c.setShadow(offset:CGSize(width:0,height:-12),blur:36,color:CGColor(red:0.13,green:0.39,blue:0.70,alpha:0.22));c.setFillColor(CGColor(gray:1,alpha:1));c.addPath(rounded);c.fillPath();c.restoreGState()
c.saveGState();c.addPath(rounded);c.clip();c.draw(cropped,in:panel);c.restoreGState()
let destination=CGImageDestinationCreateWithURL(URL(fileURLWithPath:args[3]) as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(destination,c.makeImage()!,nil);assert(CGImageDestinationFinalize(destination))
