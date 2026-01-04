import Foundation
import UIKit

/**
 设备信息协议（iOS）。
 
 与 Android Device.java 对齐。
 定义设备信息获取接口。
 */
public protocol Device {
    /// 获取设备型号
    func getDeviceModel() -> String
    
    /// 获取系统版本
    func getOSVersion() -> String
    
    /// 获取设备唯一标识符
    func getDeviceId() -> String
    
    /// 获取设备名称
    func getDeviceName() -> String
    
    /// 获取屏幕宽度（像素）
    func getScreenWidth() -> Int
    
    /// 获取屏幕高度（像素）
    func getScreenHeight() -> Int
    
    /// 获取屏幕密度
    func getScreenDensity() -> Float
    
    /// 获取设备语言
    func getDeviceLanguage() -> String
    
    /// 获取设备区域
    func getDeviceRegion() -> String
    
    /// 获取应用版本号
    func getAppVersion() -> String
    
    /// 获取应用 Build 号
    func getAppBuildNumber() -> String
    
    /// 获取 Bundle ID
    func getBundleId() -> String
    
    /// 是否为模拟器
    func isSimulator() -> Bool
}
