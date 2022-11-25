#Region Private

Function DeliveryStatus(MessageID) Export
	
	SMS.CheckRights();
	
	If IsBlankString(MessageID) Then
		Return "Pending";
	EndIf;
	
	Result = Undefined;
	SMSMessageSendingSettings = SMSMessageSendingSettings();
	
	If ValueIsFilled(SMSMessageSendingSettings.Provider) Then
		SMSOverridable.DeliveryStatus(MessageID, SMSMessageSendingSettings.Provider,
			SMSMessageSendingSettings.Username, SMSMessageSendingSettings.Password, Result);
	Else // provider is not selected
		Result = "Error";
	EndIf;
	
	Return Result;
	
EndFunction

Function SMSMessageSendingSettings() Export
	Result = New Structure("Username, Password, Provider, SenderName");
	If Common.SeparatedDataUsageAvailable() Then
		Owner = Common.MetadataObjectID("Constant.SMSProvider");
		SetPrivilegedMode(True);
		ProviderSettings = Common.ReadDataFromSecureStorage(Owner, "Password,Username,SenderName");
		SetPrivilegedMode(False);
		Result.Username = ProviderSettings.Username;
		Result.Password = ProviderSettings.Password;
		Result.SenderName = ProviderSettings.SenderName;
		Result.Provider =Constants.SMSProvider.Get();
	EndIf;
	Return New FixedStructure(Result);
EndFunction

#EndRegion