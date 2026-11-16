package cn.kelance.bojian

import androidx.core.content.FileProvider

/** 独立子类，避免与第三方 SDK 声明的 FileProvider 在清单合并时冲突。 */
class UpdateFileProvider : FileProvider()
