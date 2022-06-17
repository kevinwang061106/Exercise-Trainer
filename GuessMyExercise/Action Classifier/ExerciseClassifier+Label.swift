/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Defines the app's knowledge of the model's class labels.
*/

extension ExerciseClassifier {
    /// Represents the app's knowledge of the Exercise Classifier model's labels.
    enum Label: String, CaseIterable {
        case mistakes_high = "Mistake - High"
        case mistakes_low = "Mistake - Low"
        case mistakes_wide = "Mistake - Wide"
        case not = "Not"
        case push_up = "Push Up"

        /// A negative class that represents irrelevant actions.
        case otherAction = "Other Action"

        /// Creates a label from a string.
        /// - Parameter label: The name of an action class.
        init(_ string: String) {
            guard let label = Label(rawValue: string) else {
                let typeName = String(reflecting: Label.self)
                fatalError("Add the `\(string)` label to the `\(typeName)` type.")
            }

            self = label
        }
    }
}
