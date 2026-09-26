import SwiftUI

extension GeometryProxy {
    var hingeDivision: CGRect? {
        if #available(iOS 27.1, *) {
            return reservedRegions(kind: .division).first { $0.isActive }?.frame
        }
        return nil
    }
}
