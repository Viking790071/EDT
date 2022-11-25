#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Defines endpoints of the specified in the current infosystem massage channel.
// 
//
// Parameters:
//  MessageChannel - String. Targeted message channel ID.
//
// Returns:
//  Type: Array. Endpoints items array.
//  Array contains items of ExchangePlanRef.MessageExchange type.
//
Function MessageChannelSubscribers(Val MessagesChannel) Export
	
	QueryText =
	"SELECT
	|	SenderSettings.Recipient AS Recipient
	|FROM
	|	InformationRegister.SenderSettings AS SenderSettings
	|WHERE
	|	SenderSettings.MessagesChannel = &MessagesChannel";
	
	Query = New Query;
	Query.SetParameter("MessagesChannel", MessagesChannel);
	Query.Text = QueryText;
	
	Return Query.Execute().Unload().UnloadColumn("Recipient");
EndFunction

#EndRegion

#EndIf