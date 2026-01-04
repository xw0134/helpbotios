import Foundation

/**
 用户认证失败原因（与 WebSDK `HelpBotAuthenticationFailureReason` 对齐）。
 */
public enum HelpBotAuthenticationFailureReason: String, Codable {
    case invalidIdentityToken = "INVALID_IDENTITY_TOKEN"
    case iatIsMandatory = "IAT_IS_MANDATORY"
    case identityDataInvalid = "IDENTITY_DATA_INVALID"
    case identityDataLimitExceeded = "IDENTITY_DATA_LIMIT_EXCEEDED"
    case identityDataSyncFailed = "IDENTITY_DATA_SYNC_FAILED"
    case appAttributesLimitExceeded = "APP_ATTRIBUTES_LIMIT_EXCEEDED"
    case masterAttributesLimitExceeded = "MASTER_ATTRIBUTES_LIMIT_EXCEEDED"
    case appAttributesValidationFailed = "APP_ATTRIBUTES_VALIDATION_FAILED"
    case masterAttributesValidationFailed = "MASTER_ATTRIBUTES_VALIDATION_FAILED"
    case appAttributesSyncFailed = "APP_ATTRIBUTES_SYNC_FAILED"
    case masterAttributesSyncFailed = "MASTER_ATTRIBUTES_SYNC_FAILED"
    case identityFeatureNotEnabled = "IDENTITY_FEATURE_NOT_ENABLED"
    case userSessionExpired = "USER_SESSION_EXPIRED"
    case tokenExpired = "TOKEN_EXPIRED"
    case tokenRefreshFailed = "TOKEN_REFRESH_FAILED"
    case notAuthenticated = "NOT_AUTHENTICATED"
    case unknown = "UNKNOWN"

    public static func from(_ raw: String?) -> HelpBotAuthenticationFailureReason {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .unknown
        }
        return HelpBotAuthenticationFailureReason(rawValue: raw) ?? .unknown
    }
}


