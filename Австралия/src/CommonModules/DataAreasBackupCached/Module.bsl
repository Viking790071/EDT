#Region Internal

// Returns mapping between Russian names of application system settings fields and English from XDTO 
// package ZoneBackupControl service Manager.
// (type: {http://www.1c.ru/SaaS/1.0/XMLSchema/ZoneBackupControl}Settings).
//
// Returns:
//   FixedMap - mapping between Russian names of settings fields and English.
//
Function MapBetweenSMSettingsAndAppSettings() Export
	
	Result = New Map;
	
	Result.Insert("CreateDailyBackup", "CreateDailyBackups");
	Result.Insert("CreateMonthlyBackup", "CreateMonthlyBackups");
	Result.Insert("CreateYearlyBackup", "CreateAnnualBackups");
	Result.Insert("BackupCreationTime", "BackupCreationTime");
	Result.Insert("MonthlyBackupCreationDay", "MonthlyBackupGenerationMonthDate");
	Result.Insert("YearlyBackupCreationMonth", "EarlyBackupMonth");
	Result.Insert("YearlyBackupCreationDay", "AnnualBackupGenerationMonthDate");
	Result.Insert("KeepDailyBackups", "DailyBackupCount");
	Result.Insert("KeepMonthlyBackups", "MonthlyBackupCount");
	Result.Insert("KeepYearlyBackups", "YearlyBackupCount");
	Result.Insert("CreateDailyBackupOnUserWorkDaysOnly", "CreateDailyBackupsOnlyOnUserWorkdays");
	
	Return New FixedMap(Result);

EndFunction	

// Determines whether the application supports backup creation.
//
// Returns:
// Boolean - True if the application supports backup creation.
//
Function ServiceManagerSupportsBackup() Export
	
	SetPrivilegedMode(True);
	
	SupportedVersions = Common.GetInterfaceVersions(
		SaaS.InternalServiceManagerURL(),
		SaaS.AuxiliaryServiceManagerUsername(),
		SaaS.AuxiliaryServiceManagerUserPassword(),
		"DataAreaBackup");
		
	Return SupportedVersions.Find("1.0.1.1") <> Undefined;
	
EndFunction

// Returns backup control web service proxy.
// 
// Returns:
//   WSProxy - service manager proxy.
// 
Function BackupControlProxy() Export
	
	ServiceManagerURL = SaaS.InternalServiceManagerURL();
	If Not ValueIsFilled(ServiceManagerURL) Then
		Raise(NStr("ru = 'Не установлены параметры связи с менеджером сервиса.'; en = 'Service manager connection parameters are not specified.'; pl = 'Parametry połączenia z menedżerem usług nie są ustawione.';es_ES = 'Parámetros de la conexión con el gestor de servicio no están establecidos.';es_CO = 'Parámetros de la conexión con el gestor de servicio no están establecidos.';tr = 'Servis yöneticisiyle bağlantı parametreleri ayarlanmamış.';it = 'I parametri di connessione del manager di servizio non sono specificati.';de = 'Die Parameter der Verbindung mit dem Service Manager sind nicht festgelegt.'"));
	EndIf;
	
	ServiceAddress = ServiceManagerURL + "/ws/ZoneBackupControl?wsdl";
	Username = SaaS.AuxiliaryServiceManagerUsername();
	UserPassword = SaaS.AuxiliaryServiceManagerUserPassword();
	
	ConnectionParameters = Common.WSProxyConnectionParameters();
	ConnectionParameters.WSDLAddress = ServiceAddress;
	ConnectionParameters.NamespaceURI = "http://www.1c.ru/SaaS/1.0/WS";
	ConnectionParameters.ServiceName = "ZoneBackupControl";
	ConnectionParameters.UserName = Username; 
	ConnectionParameters.Password = UserPassword;
	ConnectionParameters.Timeout = 10;
	
	Proxy = Common.CreateWSProxy(ConnectionParameters);
	
	Return Proxy;
	
EndFunction

#EndRegion
