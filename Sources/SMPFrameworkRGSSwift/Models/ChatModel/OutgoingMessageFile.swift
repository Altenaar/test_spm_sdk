//
//  OutgoingMessageFile.swift
//  DRsdk
//
//  Created by Артем Чурсин on 24.03.2021.
//

import Foundation

/**
 * Информация о файле, прикпрепленном к сообщению
 * - version:
 * 1.0.0
 */
public class OutgoingMessageFile {
    
    let fileBase64: String
    let originalFileName: String
    
    /// Создание информации об отправляемом файле
    ///
    /// - parameter fileBase64:   текст сообщения. base64 содержимого файла
    /// - parameter originalFileName:   оригинальное название файла. (К примеру: my_image.jpg)
    public init(fileBase64: String, originalFileName: String) {
        
        self.fileBase64 = fileBase64
        self.originalFileName = originalFileName
    }
}
