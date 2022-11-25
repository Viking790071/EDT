#Region Public

// Open the form to send a new text message.
//
// Parameters:
//  RecipientsNumbers - Array - recipient numbers in format +<CountryCode><DEFCode><number>(as string).
//  Text - String - a message text with length not more than 1000 characters.
//  AdditionalParameters - Structure - additional text message sending parameters.
//    * SenderName - String - a sender name that recipients will see instead of a number.
//    * Transliterate - Boolean - True if the message text is to be transliterated before sending.
Procedure SendSMSMessage(RecipientsNumbers, Text, AdditionalParameters) Export
	
	StandardProcessing = True;
	SendSMSMessagesClientOverridable.OnSendSMSMessage(RecipientsNumbers, Text, AdditionalParameters, StandardProcessing);
	If StandardProcessing Then
		SendOptions = New Structure("RecipientsNumbers, Text, AdditionalParameters");
		SendOptions.RecipientsNumbers = RecipientsNumbers;
		SendOptions.Text = Text;
		If TypeOf(AdditionalParameters) = Type("Structure") Then
			SendOptions.AdditionalParameters = AdditionalParameters;
		Else
			SendOptions.AdditionalParameters = New Structure;
		EndIf;
		If NOT SendOptions.AdditionalParameters.Property("Transliterate") Then
			SendOptions.AdditionalParameters.Insert("Transliterate", False);
		EndIf;
		If NOT SendOptions.AdditionalParameters.Property("ContactInformationSource") Then
			SendOptions.AdditionalParameters.Insert("ContactInformationSource", "");
		EndIf;

		NotifyDescription = New NotifyDescription("CreateNewSMSMessageSettingsCheckCompleted", ThisObject, SendOptions);
		CheckForSMSMessageSendingSettings(NotifyDescription);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// If a user has no settings for sending text messages, does one of the following depending on the 
// user rights: show the text message settings form, or show a message that sending is unavailable.
//
// Parameters:
//  ResultHandler - NotifyDescription - the procedure to be called after the check is completed.
//
Procedure CheckForSMSMessageSendingSettings(ResultHandler)
	
	ClientRunParameters = StandardSubsystemsClient.ClientRunParameters();
	If ClientRunParameters.CanSendSMSMessage Then
		ExecuteNotifyProcessing(ResultHandler, True);
	Else
		If ClientRunParameters.IsFullUser Then
			NotifyDescription = New NotifyDescription("AfterSetUpSMSMessage", ThisObject, ResultHandler);
			OpenForm("CommonForm.OutboundSMSSettings",,,,,, NotifyDescription);
		Else
			MessageText = NStr("ru = 'Настройки SMS не заданы.
				|Свяжитесь с администратором.'; 
				|en = 'SMS settings are not configured.
				|Please contact the administrator.'; 
				|pl = 'Ustawienia SMS nie są skonfigurowane.
				|Skontaktuj się z administratorem.';
				|es_ES = 'Las configuraciones de SMS no están configuradas.
				|Por favor, póngase en contacto con el administrador.';
				|es_CO = 'Las configuraciones de SMS no están configuradas.
				|Por favor, póngase en contacto con el administrador.';
				|tr = 'SMS ayarları yapılandırılmadı.
				|Lütfen, yönetici ile irtibata geçin.';
				|it = 'Le impostazioni SMS non sono configurate. 
				|Contattare l''amministratore.';
				|de = 'SMS-Einstellungen sind nicht konfiguriert.
				|Wenden Sie Sich an den Administrator.'");
			ShowMessageBox(, MessageText);
		EndIf;
	EndIf;
	
EndProcedure

Procedure AfterSetUpSMSMessage(Result, ResultHandler) Export
	ClientRunParameters = StandardSubsystemsClient.ClientRunParameters();
	If ClientRunParameters.CanSendSMSMessage Then
		ExecuteNotifyProcessing(ResultHandler, True);
	EndIf;
EndProcedure

// Continues the SendSMSMessage procedure.
Procedure CreateNewSMSMessageSettingsCheckCompleted(SMSMessageSendingIsSetUp, SendOptions) Export
	
	If SMSMessageSendingIsSetUp Then
		
		ClientRunParameters = StandardSubsystemsClient.ClientRunParameters();
		If CommonClient.SubsystemExists("StandardSubsystems.Interactions")
			AND ClientRunParameters.UseOtherInteractions Then
			
			Recipients = New Array;
			ContactInformationSource = ?(SendOptions.AdditionalParameters.Property("ContactInformationSource"), SendOptions.AdditionalParameters.ContactInformationSource, "");
			Subject = ?(SendOptions.AdditionalParameters.Property("Subject"), SendOptions.AdditionalParameters.Subject, Undefined);
			
			For each ArrayElement In SendOptions.RecipientsNumbers Do
				
				If TypeOf(ArrayElement) = Type("String") Then
					PhoneNumber                = ArrayElement;
					Presentation                = ArrayElement;
					ContactInformationSource = ContactInformationSource;
				Else
					PhoneNumber                = ArrayElement.Phone;
					Presentation                = ArrayElement.Presentation;
					ContactInformationSource = ArrayElement.ContactInformationSource;
				EndIf;
				
				Recipients.Add(New Structure("Phone, Presentation, ContactInformationSource",
				PhoneNumber, Presentation, ContactInformationSource));
				
			EndDo;
			
			ModuleClientInteractions = CommonClient.CommonModule("InteractionsClient");
			ModuleClientInteractions.OpenSMSMessageSendingForm(Recipients, SendOptions.Text, Subject, SendOptions.AdditionalParameters.Transliterate);
		Else
			OpenForm("CommonForm.SMS", SendOptions);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion