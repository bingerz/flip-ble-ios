//
//  UIUtils.swift
//  Flip-BLE_Example
//
//  Created by Hanson on 2022/8/20.
//  Copyright © 2022 hanbing0604@aliyun.com. All rights reserved.
//

import Foundation

class UIUtils {
    
    static func screenWidth() -> CGFloat {
        return UIScreen.main.bounds.size.width
    }
    
    static func screenHeight() -> CGFloat {
        return UIScreen.main.bounds.size.height
    }
    
    static func color(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> UIColor {
        return UIColor(red: red/255.0, green: green/255.0, blue: blue/255.0, alpha: alpha/1.0)
    }
    
    static func createImageWithColor(_ color: UIColor) -> UIImage? {
        let rect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(color.cgColor)
        context?.fill(rect)
        let theImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return theImage
    }

    static func getTableViewHeaderView(height:Int, bgColor:UIColor) -> UIView {
        let viewWidth = screenWidth()
        let view = UIView(frame: CGRect(x: 0, y: 0, width: Int(viewWidth), height: height))
        view.backgroundColor = bgColor
        return view
    }
    
}
