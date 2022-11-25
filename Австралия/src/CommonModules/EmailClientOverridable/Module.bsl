#Region Public

// It is called before opening a new email form.
// Changing parameter StandardProcessing can cancel opening the form.
//
// Parameters:
//  SendingParameters    - Structure - see EmailOperationsClient.CreateNewEmailMessage.
//  CompletionHandler - NotifyDescription - description of the procedure that is called after 
//                                              sending email.
//  StandardProcessing - Boolean - shows whether a new email form continues opening after the 
//                                  procedure ends. If False, the email form is not opened.
Procedure BeforeOpenEmailSendingForm(SendOptions, CompletionHandler, StandardProcessing) Export
	
EndProcedure

#EndRegion