#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure) Export
	
	BeginTransaction();
	Try
		RecordSet = CreateRecordSet();
		If RecordStructure.Property("Endpoint") Then
			RecordSet.Filter.Endpoint.Set(RecordStructure.Endpoint);
		EndIf;
		
		NewRecord = RecordSet.Add();
		FillPropertyValues(NewRecord, RecordStructure);
		RecordSet.Write();
		
		WritePassword("Password", "WSPassword", RecordStructure);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Updates a register record based on the passed structure values.
Procedure UpdateRecord(RecordStructure) Export
	
	BeginTransaction();
	Try
		RecordManager = CreateRecordManager();
		If RecordStructure.Property("Endpoint") Then
			RecordManager.Endpoint = RecordStructure.Endpoint;
		EndIf;
		
		RecordManager.Read();
		FillPropertyValues(RecordManager, RecordStructure);
		RecordManager.Write();
		
		WritePassword("Password", "WSPassword", RecordStructure);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// For internal use.
// 
Function TransportSettingsWS(Endpoint, AuthenticationParameters = Undefined) Export
	
	Result = New Structure;
	Result.Insert("DefaultExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.WS);
	Result.Insert("WSWebServiceURL");
	Result.Insert("WSUsername");
	Result.Insert("WSRememberPassword");
	Result.Insert("WSPassword");
	
	Query = New Query(
	"SELECT
	|	TransportSettings.WebServiceAddress AS WSWebServiceURL,
	|	TransportSettings.UserName AS WSUsername,
	|	TransportSettings.RememberPassword AS WSRememberPassword
	|FROM
	|	InformationRegister.MessageExchangeTransportSettings AS TransportSettings
	|WHERE
	|	TransportSettings.Endpoint = &Endpoint");
	Query.SetParameter("Endpoint", Endpoint);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillPropertyValues(Result, Selection);
	EndIf;
	
	SetPrivilegedMode(True);
	WSPassword = Common.ReadDataFromSecureStorage(Endpoint, "WSPassword", True);
	SetPrivilegedMode(False);
	
	If TypeOf(WSPassword) = Type("String")
		Or WSPassword = Undefined Then
		
		Result.Insert("WSPassword", WSPassword);
	Else
		Raise NStr("ru='Ошибка при извлечении пароля из безопасного хранилища.'; en = 'An error occurred while extracting password from secure storage.'; pl = 'Błąd podczas pobierania hasła z bezpiecznej przechowalni.';es_ES = 'Error al extraer la contraseña del almacenamiento seguro.';es_CO = 'Error al extraer la contraseña del almacenamiento seguro.';tr = 'Güvenli depolamadan şifre alınırken hata oluştu.';it = 'Si è registrato un errore durante l''estrazione della password dall''archivio sicuro.';de = 'Fehler beim Abrufen des Passworts vom sicheren Speicher.'");
	EndIf;
	
	If TypeOf(AuthenticationParameters) = Type("Structure") Then // Initializing exchange using the current user name.
		
		If AuthenticationParameters.UseCurrentUser Then
			
			Result.WSUsername = InfoBaseUsers.CurrentUser().Name;
			
		EndIf;
		
		Password = Undefined;
		
		If AuthenticationParameters.Property("Password", Password)
			AND Password <> Undefined Then // The password is specified on the client
			
			Result.WSPassword = Password;
			
		Else // The password is not specified on the client.
			
			Password = DataSynchronizationPassword(Endpoint);
			Result.WSPassword = ?(Password = Undefined, "", Password);
			
		EndIf;
		
	ElsIf TypeOf(AuthenticationParameters) = Type("String") Then
		Result.WSPassword = AuthenticationParameters;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Private

Procedure WritePassword(PasswordNameInStructure, PasswordNameOnWrite, RecordStructure)
	
	If RecordStructure.Property(PasswordNameInStructure) Then
		SetPrivilegedMode(True);
		Common.WriteDataToSecureStorage(RecordStructure.Endpoint,
			RecordStructure[PasswordNameInStructure], PasswordNameOnWrite);
		SetPrivilegedMode(False);
	EndIf;
	
EndProcedure

Function DataSynchronizationPassword(InfobaseNode)
	
	Password = Undefined;
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		SetPrivilegedMode(True);
		Password = SessionParameters.DataSynchronizationPasswords.Get(InfobaseNode);
	EndIf;
	
	Return Password;
	
EndFunction

#EndRegion

#EndIf