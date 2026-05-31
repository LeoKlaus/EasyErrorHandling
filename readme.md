# EasyErrorHandling

Super simple library to surface runtime errors to users and log them.

## Localization

You can manually add the following strings to the string catalog of your app to localize EasyErrorHandling (you can also check `Localizable.xcstrings` for keys):

1. Shown below the error message when `blockUserInteraction` is `true`.
```
Check the logs for more details.
```

2. Text for the "copy to clipboard" button in the log sheet
```
Copy to clipboard
```

3. Text for the "dismiss" button in the log sheet
```
Dismiss
```

4. Title for the log sheet
```
Logs
```

5. Title of the error alert when `blockUserInteraction` is `true`. %@ is `performedTask`
```
Error while %@
```

6. Task description of the log export task (this generally shouldn't fail)
```
exporting logs
```

7. Text for the dismiss button of the error alert when `blockUserInteraction` is `true`
```
Ok
```

8. Text shown below error toasts
```
Tap for more information
```
