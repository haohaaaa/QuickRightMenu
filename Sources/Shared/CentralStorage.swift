import Foundation

public struct CentralStorage {
    public static var userHomeDirectory: String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }
    
    /// Path inside sandboxed extension container: ~/Library/Application Support/QuickRightMenu/
    public static var containerAppSupportURL: URL {
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/QuickRightMenu", isDirectory: true)
    }
    
    /// Global central configuration root: ~/.quickrightmenu/
    public static var rootURL: URL {
        let directURL = URL(fileURLWithPath: userHomeDirectory).appendingPathComponent(".quickrightmenu", isDirectory: true)
        if FileManager.default.fileExists(atPath: directURL.path) {
            return directURL
        }
        let containerHome = NSHomeDirectory()
        let containerLink = URL(fileURLWithPath: containerHome).appendingPathComponent(".quickrightmenu", isDirectory: true)
        if FileManager.default.fileExists(atPath: containerLink.path) {
            return containerLink
        }
        return directURL
    }
    
    public static var configFileURL: URL {
        let containerConfig = containerAppSupportURL.appendingPathComponent("config.json", isDirectory: false)
        if FileManager.default.fileExists(atPath: containerConfig.path) {
            return containerConfig
        }
        return rootURL.appendingPathComponent("config.json", isDirectory: false)
    }
    
    public static var commandsDirectoryURL: URL {
        return rootURL.appendingPathComponent("commands", isDirectory: true)
    }
    
    public static var templatesDirectoryURL: URL {
        let containerTpl = containerAppSupportURL
            .appendingPathComponent("file_template", isDirectory: true)
        if FileManager.default.fileExists(atPath: containerTpl.path) {
            return containerTpl
        }
        let directTpl = URL(fileURLWithPath: userHomeDirectory)
            .appendingPathComponent(".quickrightmenu/file_template", isDirectory: true)
        if FileManager.default.fileExists(atPath: directTpl.path) {
            return directTpl
        }
        return containerTpl
    }
    
    public static var logFileURL: URL {
        return rootURL.appendingPathComponent("app.log", isDirectory: false)
    }
    
    public static var extensionContainerAppSupportURL: URL {
        return URL(fileURLWithPath: userHomeDirectory)
            .appendingPathComponent("Library/Containers/com.liaowenbin.QuickRightMenu.Extension/Data/Library/Application Support/QuickRightMenu", isDirectory: true)
    }
    
    public static var extensionContainerTemplatesURL: URL {
        return extensionContainerAppSupportURL.appendingPathComponent("file_template", isDirectory: true)
    }
    
    public static var extensionContainerCommandsURL: URL {
        return extensionContainerAppSupportURL.appendingPathComponent("commands", isDirectory: true)
    }
    
    public static func ensureDirectoriesExist() {
        let fm = FileManager.default
        try? fm.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
        try? fm.createDirectory(at: commandsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        try? fm.createDirectory(at: templatesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        try? fm.createDirectory(at: extensionContainerAppSupportURL, withIntermediateDirectories: true, attributes: nil)
        try? fm.createDirectory(at: extensionContainerTemplatesURL, withIntermediateDirectories: true, attributes: nil)
        try? fm.createDirectory(at: extensionContainerCommandsURL, withIntermediateDirectories: true, attributes: nil)
        
        let defaultTxtURL = templatesDirectoryURL.appendingPathComponent("纯文本.txt")
        if !fm.fileExists(atPath: defaultTxtURL.path) {
            let files = (try? fm.contentsOfDirectory(atPath: templatesDirectoryURL.path)) ?? []
            if files.filter({ !$0.hasPrefix(".") }).isEmpty {
                try? "".write(to: defaultTxtURL, atomically: true, encoding: .utf8)
            }
        }
        
        // Link .quickrightmenu and file_template into extension container data directory
        let containerDataURL = URL(fileURLWithPath: userHomeDirectory)
            .appendingPathComponent("Library/Containers/com.liaowenbin.QuickRightMenu.Extension/Data")
        let linkInContainer = containerDataURL.appendingPathComponent(".quickrightmenu")
        if fm.fileExists(atPath: containerDataURL.path) && !fm.fileExists(atPath: linkInContainer.path) {
            try? fm.createSymbolicLink(at: linkInContainer, withDestinationURL: rootURL)
        }
        let tplLinkInContainer = containerDataURL.appendingPathComponent("file_template")
        if fm.fileExists(atPath: containerDataURL.path) && !fm.fileExists(atPath: tplLinkInContainer.path) {
            try? fm.createSymbolicLink(at: tplLinkInContainer, withDestinationURL: templatesDirectoryURL)
        }
        
        syncTemplatesToContainer()
    }
    
    public static func syncTemplatesToContainer() {
        let fm = FileManager.default
        let sourceDir = templatesDirectoryURL
        let targetDir = extensionContainerTemplatesURL
        
        try? fm.createDirectory(at: targetDir, withIntermediateDirectories: true, attributes: nil)
        
        guard let sourceItems = try? fm.contentsOfDirectory(atPath: sourceDir.path) else { return }
        let validSources = sourceItems.filter { !$0.hasPrefix(".") }
        let sourceSet = Set(validSources)
        
        let targetItems = (try? fm.contentsOfDirectory(atPath: targetDir.path)) ?? []
        for targetItem in targetItems {
            if !targetItem.hasPrefix(".") && !sourceSet.contains(targetItem) {
                try? fm.removeItem(at: targetDir.appendingPathComponent(targetItem))
            }
        }
        
        for name in sourceSet {
            let srcFile = sourceDir.appendingPathComponent(name)
            let dstFile = targetDir.appendingPathComponent(name)
            
            var shouldCopy = true
            if let srcAttr = try? fm.attributesOfItem(atPath: srcFile.path),
               let dstAttr = try? fm.attributesOfItem(atPath: dstFile.path),
               let srcMod = srcAttr[.modificationDate] as? Date,
               let dstMod = dstAttr[.modificationDate] as? Date,
               let srcSize = srcAttr[.size] as? NSNumber,
               let dstSize = dstAttr[.size] as? NSNumber,
               srcMod == dstMod && srcSize == dstSize {
                shouldCopy = false
            }
            
            if shouldCopy {
                try? fm.removeItem(at: dstFile)
                try? fm.copyItem(at: srcFile, to: dstFile)
            }
        }
    }
    
    public static func syncToExtensionContainer(configData: Data) {
        let fm = FileManager.default
        let containerDir = extensionContainerAppSupportURL
        try? fm.createDirectory(at: containerDir, withIntermediateDirectories: true, attributes: nil)
        
        let targetConfigURL = containerDir.appendingPathComponent("config.json", isDirectory: false)
        try? configData.write(to: targetConfigURL, options: .atomic)
    }
    
    public static func currentTemplateFiles() -> [String] {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(atPath: templatesDirectoryURL.path)) ?? []
        return items.filter { !$0.hasPrefix(".") }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    
    public static func log(source: String, message: String) {
        let line = "\(Date()) \(source): \(message)\n"
        let targets = [
            logFileURL,
            containerAppSupportURL.appendingPathComponent("app.log", isDirectory: false)
        ]
        guard let data = line.data(using: .utf8) else { return }
        for fileURL in targets {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }
}
