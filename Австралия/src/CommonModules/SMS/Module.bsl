#Region Public

// It sends a text message via a configured service provider and returns message ID. 
//
// Parameters:
//  RecipientsNumbers - Array - an array of strings containing recipient numbers in format +7ХХХХХХХХХХ.
//  Text - String - a message text, the maximum length varies depending on operators.
//  SenderName - String - a sender name that recipients will see instead of a number.
//  Transliterate - Boolean - True if the message text is to be transliterated before sending.
//
// Returns:
//  Structure - a sending result:
//    * SentMessages - Array - an array of structures:
//      ** RecipientNumber - String - a number of text message recipient.
//      ** MessageID - String - a text message ID assigned by a provider to track delivery.
//    * ErrorDescription - String - a user presentation of an error. If the string is empty, there is no error.
//
Function SendSMSMessage(RecipientsNumbers, Val Text, SenderName = Undefined, Transliterate = False) Export
	
	CheckRights();
	
	Result = New Structure("SentMessages,ErrorDescription", New Array, "");
	
	If Transliterate Then
		Text = StringFunctionsClientServer.LatinString(Text);
	EndIf;
	
	If Not SMSMessageSendingSetupCompleted() Then
		Result.ErrorDescription = NStr("ru = 'Неверные настройки поставщика SMS.'; en = 'Invalid SMS provider settings.'; pl = 'Niepoprawne ustawienia operatora SMS.';es_ES = 'Configuraciones del proveedor de SMS no válidas.';es_CO = 'Configuraciones del proveedor de SMS no válidas.';tr = 'Geçersiz SMS sağlayıcı ayarları.';it = 'Impostazioni di provider SMS non valide.';de = 'Ungültige SMS-Anbieter-Einstellungen.'");
		Return Result;
	EndIf;
	
	SMSMessageSendingSettings = SendSMSMessagesCached.SMSMessageSendingSettings();
	If SenderName = Undefined Then
		SenderName = SMSMessageSendingSettings.SenderName;
	EndIf;
	
	SMSProviders = New Map;
	For Each Provider In Metadata.Enums.SMSProviders.EnumValues Do
		SMSProviders.Insert(Enums.SMSProviders[Provider.Name], Provider.Name);
	EndDo;
	
	If ValueIsFilled(SMSMessageSendingSettings.Provider) Then 
	
		SendOptions = New Structure;
		SendOptions.Insert("RecipientsNumbers", RecipientsNumbers);
		SendOptions.Insert("Text", Text);
		SendOptions.Insert("SenderName", SenderName);
		SendOptions.Insert("Username", SMSMessageSendingSettings.Username);
		SendOptions.Insert("Password", SMSMessageSendingSettings.Password);
		SendOptions.Insert("Provider", SMSMessageSendingSettings.Provider);
		
		DataProcessorManager = AdditionalReportsAndDataProcessors.GetExternalDataProcessorsObject(SMSMessageSendingSettings.Provider);
		DataProcessorManager.SendSMS(SendOptions, Result);
		
	EndIf;
		
	MethodName = String(DataProcessorManager) + "SendSMS";
	CommonClientServer.CheckParameter(MethodName, "Result", Result,
	Type("Structure"), New Structure("SentMessages,ErrorDescription", Type("Array"), Type("String")));
	
	If Not ValueIsFilled(Result.ErrorDescription) AND Not ValueIsFilled(Result.SentMessages) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Ошибка завершения процедуры SMSOverridable.SendSMSMessage:
			|Требуется хотя бы один из параметров: ErrorDescription, SentMessages.
			|Поставщик: %1.'; 
			|en = 'Error completing procedure SMSOverridable.SendSMSMessage:
			|At least one of the parameters is required: ErrorDescription, SentMessages.
			|Provider: %1.'; 
			|pl = 'Błąd podczas zakończenia procedury SMSOverridable.SendSMSMessage:
			|Wymagany jest co najmniej jeden z parametrów: ErrorDescription, SentMessages.
			|Operator: %1.';
			|es_ES = 'Error al finalizar el procedimiento SMSOverridable.SendSMSMessage:
			|Se requiere al menos uno de los parámetros: ErrorDescription, SentMessages.
			|Proveedor: %1.';
			|es_CO = 'Error al finalizar el procedimiento SMSOverridable.SendSMSMessage:
			|Se requiere al menos uno de los parámetros: ErrorDescription, SentMessages.
			|Proveedor: %1.';
			|tr = 'SMSOverridable.SendSMSMessage prosedürü tamamlanırken hata oluştu:
			|Parametrelerden en az biri gerekli: ErrorDescription, SentMessages.
			|Sağlayıcı: %1.';
			|it = 'Errore durante il completamento della procedura SMS Sovrascrivibile. InvioMessaggioSMS:
			| è richiesto almeno uno dei parametri: DescrizioneErrore, MessaggiInviati. 
			|Provider: %1.';
			|de = 'Fehler beim Abschließen der Prozedur SMSOverridable.SendSMSMessage:
			|Zumindest ein der Parameter ist benötigt: ErrorDescription, SentMessages.
			|Anbieter: %1.'", CommonClientServer.DefaultLanguageCode()),
		SMSMessageSendingSettings.Provider);
	EndIf;
	
	If Result.SentMessages.Count() > 0 Then
		CommonClientServer.Validate(
		TypeOf(Result.SentMessages[0]) = Type("Structure"),
		StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Неверный тип значения в коллекции Result.SentMessages.
			|Фактический тип: %1. Ожидаемый тип: Structure.'; 
			|en = 'Invalid value type in Result.SentMessages collection.
			|Actual type: %1. Expected type: Structure.'; 
			|pl = 'Niepoprawny typ wartości w kolekcji Result.SentMessages.
			|Faktyczny typ: %1. Oczekiwany typ: Struktura.';
			|es_ES = 'Tipo de valor no válido en la colección Result.SentMessages.
			|Tipo real: %1. Tipo esperado: Estructura.';
			|es_CO = 'Tipo de valor no válido en la colección Result.SentMessages.
			|Tipo real: %1. Tipo esperado: Estructura.';
			|tr = 'Result.SentMessages koleksiyonunda geçersiz değer türü.
			|Gerçekleşen tür: %1. Beklenen tür: Yapı.';
			|it = 'Tipo di valore non valido nella collezione Risultato.MessaggiInviati. 
			|Tipo effettivo: %1. Tipo previsto: Struttura.';
			|de = 'Ungültiger Typ des Werts in Sammlung Result.SentMessages.
			|Aktueller Typ: %1. Erwarteter Typ: Struktur.'"),
		TypeOf(Result.SentMessages[0])),
		MethodName);
		For Index = 0 To Result.SentMessages.Count() - 1 Do
			CommonClientServer.CheckParameter(
			"SendSMS",
			StringFunctionsClientServer.SubstituteParametersToString("Result.SentMessages[%1]", Format(Index, "NZ=; NG=0")),
			Result.SentMessages[Index],
			Type("Structure"),
			New Structure("RecipientNumber,MessageID", Type("String"), Type("String")));
		EndDo;
	EndIf;
	
	Return Result;
	
EndFunction

// The function requests for a message delivery status from service provider.
//
// Parameters:
//  MessageID - String - ID assigned to a text message upon sending.
//
// Returns:
//  String - a message delivery status returned from service provider:
//           Pending - the message is not processed by the service provider yet (in queue).
//           BeingSent - the message is in the sending queue at the provider.
//           Sent - the message is sent, a delivery confirmation is awaited.
//           NotSent - the message is not sent (insufficient account balance or operator network congestion).
//           Delivered - the message is delivered to the addressee.
//           NotDelivered - cannot deliver the message (the subscriber is not available or delivery 
//                              confirmation from the subscriber is timed out).
//           Error - cannot get a status from service provider (unknown status).
//
Function DeliveryStatus(Val MessageID) Export
	
	CheckRights();
	
	If IsBlankString(MessageID) Then
		Return "Pending";
	EndIf;
	
	Result = Undefined;
	SMSMessageSendingSettings = SendSMSMessagesCached.SMSMessageSendingSettings();
	
	If ValueIsFilled(SMSMessageSendingSettings.Provider) Then
		
		CommandParameters = New Structure;
		CommandParameters.Insert("MessageID",	MessageID);	
		CommandParameters.Insert("Provider",	SMSMessageSendingSettings.Provider);
		CommandParameters.Insert("Login",		SMSMessageSendingSettings.Login);
		CommandParameters.Insert("Password",	SMSMessageSendingSettings.Password); 
		
		DataProcessorManager = AdditionalReportsAndDataProcessors.GetExternalDataProcessorsObject(SMSMessageSendingSettings.Provider);
		DataProcessorManager.DeliveryStatus(CommandParameters, Result);

	Else
		Result = "Error";
	EndIf;
	
	Return Result;
	
EndFunction

// This function checks whether saved text message sending settings are correct.
//
// Returns:
//  Boolean - True if text message sending is set up.
Function SMSMessageSendingSetupCompleted() Export
	
	SetPrivilegedMode(True);
	SMSMessageSendingSettings = SendSMSMessagesCached.SMSMessageSendingSettings();
	SetPrivilegedMode(False);
	
	If ValueIsFilled(SMSMessageSendingSettings.Provider) Then
		
		Cancel = False;
		DataProcessorManager = AdditionalReportsAndDataProcessors.GetExternalDataProcessorsObject(SMSMessageSendingSettings.Provider);
		DataProcessorManager.ValidateSMSSettings(SMSMessageSendingSettings, Cancel);
		
		Return Not Cancel;
	EndIf;
	
	Return False;
	
EndFunction

// This function checks whether the current user can send text messages.
// 
// Returns:
//  Boolean - True if text message sending is set up and the current user has sufficient rights to send text messages.
//
Function CanSendSMSMessage() Export
	Return AccessRight("View", Metadata.CommonForms.SMS) AND SMSMessageSendingSetupCompleted() Or Users.IsFullUser();
EndFunction

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Update the infobase.

// Intended for moving passwords to a secure storage.
// This procedure is used in the infobase update handler.
Procedure MovePasswordsToSecureStorage() Export
	SMSMessageSenderUsername = Constants.DeleteSMSMessageSenderUsername.Get();
	SMSMessageSenderPassword = Constants.DeleteSMSMessageSenderPassword.Get();
	Owner = Common.MetadataObjectID("Constant.SMSProvider");
	SetPrivilegedMode(True);
	Common.WriteDataToSecureStorage(Owner, SMSMessageSenderPassword);
	Common.WriteDataToSecureStorage(Owner, SMSMessageSenderUsername, "Username");
	SetPrivilegedMode(False);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddClientParameters. 
Procedure OnAddClientParameters(Parameters) Export
	Parameters.Insert("CanSendSMSMessage", CanSendSMSMessage());
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources. 
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	PermissionRequests.Add(
		ModuleSafeModeManager.RequestToUseExternalResources(AdditionalPermissions()));
	
EndProcedure

#EndRegion

#Region Private

Function AdditionalPermissions()
	Permissions = New Array;
	SMSOverridable.OnGetPermissions(Permissions);
	
	Return Permissions;
EndFunction

Procedure CheckRights() Export
	If Not AccessRight("View", Metadata.CommonForms.SMS) Then
		Raise NStr("ru = 'Недостаточно прав для выполнения операции.'; en = 'Insufficient rights to perform the operation.'; pl = 'Niewystarczające uprawnienia do wykonania operacji.';es_ES = 'Insuficientes derechos para realizar la operación.';es_CO = 'Insuficientes derechos para realizar la operación.';tr = 'İşlem için gerekli yetkiler yok.';it = 'Autorizzazioni insufficienti per eseguire l''operazione.';de = 'Unzureichende Rechte auf Ausführen der Operation.'");
	EndIf;
EndProcedure

Function PrepareHTTPRequest(ResourceAddress, QueryOptions) Export
	
	Headers = New Map;
	Headers.Insert("Content-Type", "application/x-www-form-urlencoded");
	
	If TypeOf(QueryOptions) = Type("String") Then
		ParameterString = QueryOptions;
	Else
		ParametersList = New Array;
		For Each Parameter In QueryOptions Do
			ParametersList.Add(Parameter.Key + "=" + EncodeString(Parameter.Value, StringEncodingMethod.URLEncoding));
		EndDo;
		ParameterString = StrConcat(ParametersList, "&");
	EndIf;
	
	HTTPRequest = New HTTPRequest(ResourceAddress, Headers);
	HTTPRequest.SetBodyFromString(ParameterString);
	
	Return HTTPRequest;

EndFunction

#EndRegion
