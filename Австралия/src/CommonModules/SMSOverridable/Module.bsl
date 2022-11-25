#Region Public

// Sends a text message via a configured service provider.
//
// Parameters:
//  SendingParameters - Structure -
//    Provider - EnumRef.SMSProviders - a text message sending service provider.
//    RecipientsNumbers - Array - an array of strings containing recipient numbers in format +7ХХХХХХХХХХ.
//    Text - String - a message text, the maximum length varies depending on operators.
//    SenderName - String - a sender name that recipients will see instead of a number.
//    Username - String - a username used to access the text message sending service.
//    Password - String - a password used to access the text message sending service.
//  Result - Structure - (return value):
//    SentMessages - an array of structures:
//      RecipientNumber - String - a recipient number from the RecipientsNumbers array.
//      MessageID - String - a text message ID by which delivery status can be requested.
//    ErrorDescription - String - a user presentation of an error. If the string is empty, there is no error.
//
Procedure SendSMSMessage(SendOptions, Result) Export
	
	
	
EndProcedure

// This procedure requests for text message delivery status from service provider.
//
// Parameters:
//  MessageID - String - ID assigned to a text message upon sending.
//  Provider - EnumRef.SMSProviders - a text message sending service provider.
//  Username - String - a username used to access the text message sending service.
//  Password - String - a password used to access the text message sending service.
//  Result - String - (return value) a delivery status, see details of the SMSMessageSending.
//                                DeliveryStatus function.
Procedure DeliveryStatus(MessageID, Provider, Username, Password, Result) Export 
	
	
	
EndProcedure

// This function checks whether saved text message sending settings are correct.
//
// Parameters:
//  SMSMessageSendingSettings - Structure - details of the current text message sending settings:
//   * Provider - EnumRef.SMSProviders.
//   * Username - String.
//   * Password - String.
//   * SenderName - String.
//  Cancel - Boolean - set this parameter to True if the settings are not filled in or filled in incorrectly.
//
Procedure OnCheckSMSMessageSendingSettings(SMSMessageSendingSettings, Cancel) Export

EndProcedure

// This procedure supplements the list of permissions for sending text messages.
//
// Parameters:
//  Permissions - Array - an array of objects being returned by one of functions SafeModeManager.Permission*().
//
Procedure OnGetPermissions(Permissions) Export
	
EndProcedure

#EndRegion
