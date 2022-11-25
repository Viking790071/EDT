#Region Private

Function GetSettingsFormParameters(Val DataArea) Export
	
	ErrorInformation = Undefined;
	Parameters = Proxy().GetSettingsFormParameters(
		DataArea,
		AreaKey(),
		ErrorInformation);
	// Do not localize the operation name.
	HandleWebServiceErrorInfo(ErrorInformation, "GetSettingsFormParameters");
	
	Return XDTOSerializer.ReadXDTO(Parameters);
	
EndFunction

Function GetAreaSettings(Val DataArea) Export
	
	ErrorInformation = Undefined;
	Parameters = Proxy().GetZoneSettings(
		DataArea,
		AreaKey(),
		ErrorInformation);
	HandleWebServiceErrorInfo(ErrorInformation, "GetZoneSettings"); // Do not localize the operation name.
	
	Return XDTOSerializer.ReadXDTO(Parameters);
	
EndFunction

Procedure SetAreaSettings(Val DataArea, Val NewSettings, Val InitialSettings) Export
	
	ErrorInformation = Undefined;
	Proxy().SetZoneSettings(
		DataArea,
		AreaKey(),
		XDTOSerializer.WriteXDTO(NewSettings),
		XDTOSerializer.WriteXDTO(InitialSettings),
		ErrorInformation);
	HandleWebServiceErrorInfo(ErrorInformation, "SetZoneSettings"); // Do not localize the operation name.
	
EndProcedure

Function GetStandardSettings() Export
	
	ErrorInformation = Undefined;
	Parameters = Proxy().GetDefaultSettings(
		ErrorInformation);
	HandleWebServiceErrorInfo(ErrorInformation, "GetDefaultSettings"); // Do not localize the operation name.
	
	Return XDTOSerializer.ReadXDTO(Parameters);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

Function AreaKey()
	
	SetPrivilegedMode(True);
	Return Constants.DataAreaKey.Get();
	
EndFunction

Function Proxy()
	
	SetPrivilegedMode(True);
	ServiceManagerURL = SaaS.InternalServiceManagerURL();
	If Not ValueIsFilled(ServiceManagerURL) Then
		Raise(NStr("ru = 'Не установлены параметры связи с менеджером сервиса.'; en = 'Service manager connection parameters are not specified.'; pl = 'Parametry połączenia z menedżerem usług nie są ustawione.';es_ES = 'Parámetros de la conexión con el gestor de servicio no están establecidos.';es_CO = 'Parámetros de la conexión con el gestor de servicio no están establecidos.';tr = 'Servis yöneticisiyle bağlantı parametreleri ayarlanmamış.';it = 'I parametri di connessione del manager di servizio non sono specificati.';de = 'Die Parameter der Verbindung mit dem Service Manager sind nicht festgelegt.'"));
	EndIf;
	
	ServiceAddress = ServiceManagerURL + "/ws/ZoneBackupControl_1_0_2_1?wsdl";
	Username = SaaS.AuxiliaryServiceManagerUsername();
	UserPassword = SaaS.AuxiliaryServiceManagerUserPassword();
	
	ConnectionParameters = Common.WSProxyConnectionParameters();
	ConnectionParameters.WSDLAddress = ServiceAddress;
	ConnectionParameters.NamespaceURI = "http://www.1c.ru/1cFresh/ZoneBackupControl/1.0.2.1";
	ConnectionParameters.ServiceName = "ZoneBackupControl_1_0_2_1";
	ConnectionParameters.UserName = Username; 
	ConnectionParameters.Password = UserPassword;
	ConnectionParameters.Timeout = 10;
	
	Proxy = Common.CreateWSProxy(ConnectionParameters);
	
	Return Proxy;
	
EndFunction

// Handles web service errors.
// If the passed error info is not empty, writes the error details to the event log and raises an 
// exception with the brief error description.
// 
//
Procedure HandleWebServiceErrorInfo(Val ErrorInformation, Val OperationName)
	
	SaaS.HandleWebServiceErrorInfo(
		ErrorInformation,
		DataAreaBackup.SubsystemNameForEventLogEvents(),
		"ZoneBackupControl", // Do not localize.
		OperationName);
	
EndProcedure

#EndRegion
