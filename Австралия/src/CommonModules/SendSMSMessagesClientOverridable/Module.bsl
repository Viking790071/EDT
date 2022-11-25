#Region Public

// Open the form to send a new text message.
//
// Parameters:
//   RecipientsNumbers - Array - recipient numbers in format +<CountryCode><DEFCode><number>(as string).
//   Text - String - a message text with length not more than 1000 characters.
//   AdditionalParameters - Structure - additional text message sending parameters.
//          * SenderName - String - a sender name that recipients will see instead of a number.
//          * Transliterate - Boolean - True if the message text is to be transliterated before sending.
//   StandardProcessing - Boolean - a flag showing whether the standard processing of text message sending is to be executed.
Procedure OnSendSMSMessage(RecipientsNumbers, Text, AdditionalParameters, StandardProcessing) Export
	
EndProcedure

// This procedure defines the provider page URL in the Internet.
//
// Parameters:
//  Provider - EnumRef.SMSProviders - a text message sending service provider.
//  InternetAddress - String - a provider page URL in the Internet.
Procedure OnGetProviderInternetAddress(Provider, InternetAddress) Export
	
	
	
EndProcedure

#EndRegion
