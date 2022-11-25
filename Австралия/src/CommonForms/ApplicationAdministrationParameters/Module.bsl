
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Common.FileInfobase() AND Parameters.PromptForClusterAdministrationParameters Then
		Raise NStr("ru = 'Настройка параметров кластера серверов доступна только в клиент-серверном режиме работы.'; en = 'Setting of the server cluster parameters is available only in the client/server mode.'; pl = 'Ustawienie parametrów klastra serwerów jest dostępne tylko w trybie klient/serwer.';es_ES = 'Configuración de los parámetros del clúster del servidor está disponible solo en el modo del cliente/servidor.';es_CO = 'Configuración de los parámetros del clúster del servidor está disponible solo en el modo del cliente/servidor.';tr = 'Sunucu kümesi parametrelerinin ayarlanması sadece istemci / sunucu modunda kullanılabilir.';it = 'La configurazione delle impostazioni del cluster di server è disponibile solo in modalità client-server.';de = 'Die Einstellung der Server-Cluster-Parameter ist nur im Client / Server-Modus verfügbar.'");
	EndIf;
	
	If Parameters.PromptForClusterAdministrationParameters
		AND CommonClientServer.IsOSXClient() Then
		Return; // Cancel is set in OnOpen.
	EndIf;
	
	SeparatedDataUsageAvailable = Common.SeparatedDataUsageAvailable();
	
	If Parameters.AdministrationParameters = Undefined Then
		AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
	Else
		AdministrationParameters = Parameters.AdministrationParameters;
	EndIf;
	
	IsNecessaryToInputAdministrationParameters();
	
	If SeparatedDataUsageAvailable Then
		
		InfobaseUser = InfoBaseUsers.FindByName(
		AdministrationParameters.InfobaseAdministratorName);
		If InfobaseUser <> Undefined Then
			IBAdministratorID = InfobaseUser.UUID;
		EndIf;
		Users.FindAmbiguousIBUsers(Undefined, IBAdministratorID);
		IBAdministrator = Catalogs.Users.FindByAttribute("IBUserID", IBAdministratorID);
		
	EndIf;
	
	If Not IsBlankString(Parameters.Title) Then
		Title = Parameters.Title;
	EndIf;
	
	If IsBlankString(Parameters.NoteLabel) Then
		Items.NoteLabel.Visible = False;
	Else
		Items.NoteLabel.Title = Parameters.NoteLabel;
	EndIf;
	
	FillPropertyValues(ThisObject, AdministrationParameters);
	
	Items.RunMode.CurrentPage = ?(SeparatedDataUsageAvailable, Items.SeparatedMode, Items.SharedMode);
	Items.IBAdministrationGroup.Visible = Parameters.PromptForIBAdministrationParameters;
	Items.ClusterAdministrationGroup.Visible = Parameters.PromptForClusterAdministrationParameters;
	
	If CommonClientServer.IsLinuxClient() Then
		
		ConnectionType = "RAS";
		Items.ConnectionType.Visible = False;
		Items.ManagementParametersGroup.ShowTitle = True;
		Items.ManagementParametersGroup.Representation = UsualGroupRepresentation.WeakSeparation;
		
	EndIf;
	
	Items.ConnectionTypeGroup.CurrentPage = ?(ConnectionType = "COM", Items.COMGroup, Items.RASGroup);
	
	If CommonClientServer.IsMobileClient() Then
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Parameters.PromptForClusterAdministrationParameters
		AND CommonClientServer.IsOSXClient() Then
		Cancel = True;
		MessageText = NStr("ru = 'Подключение к кластеру серверов недоступно в клиенте под управлением ОС X.'; en = 'Connection to server cluster is not available on the client running OS X.'; pl = 'Podłączenie do klastra serwerów nie jest dostępne w kliencie zarządzanym przez OS X.';es_ES = 'La conexión al clúster de los servidores no está disponible en el cliente gestionado con OS X.';es_CO = 'La conexión al clúster de los servidores no está disponible en el cliente gestionado con OS X.';tr = 'Bir sunucu kümesine bağlantı, X tabanlı bir istemcide kullanılamaz.';it = 'Connessione al cluster di server non disponibile per il client con Sistema Operativo X.';de = 'Die Verbindung zum Server-Cluster ist im Client mit OS X nicht verfügbar.'");
		ShowMessageBox(,MessageText);
		Return;
	EndIf;
	
	If Not AdministrationParametersInputRequired Then
		Try
			CheckAdministrationParameters(AdministrationParameters);
		Except
			Return; // Processing not required. The form will be opened as usual.
		EndTry;
		Cancel = True;
		ExecuteNotifyProcessing(ThisObject.OnCloseNotifyDescription, AdministrationParameters);
	EndIf;
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Not Parameters.PromptForIBAdministrationParameters Then
		Return;
	EndIf;
	
	If Common.SeparatedDataUsageAvailable() Then
		
		If Not ValueIsFilled(IBAdministrator) Then
			Return;
		EndIf;
		
		FieldName = "IBAdministrator";
		
		InfobaseUser = Undefined;
		GetIBAdministrator(InfobaseUser);
		If InfobaseUser = Undefined Then
			CommonClientServer.MessageToUser(NStr("ru = 'Указанный пользователь не имеет доступа к информационной базе.'; en = 'This user is not allowed to access the infobase.'; pl = 'Wskazany użytkownik nie ma dostępu do bazy informacyjnej.';es_ES = 'El usuario especificado no tiene accedo para la infobase.';es_CO = 'El usuario especificado no tiene accedo para la infobase.';tr = 'Bu kullanıcının Infobase erişimi yok.';it = 'L''utente indicato non ha accesso al database informatico.';de = 'Der angegebene Benutzer hat keinen Zugriff auf die Infobase.'"),,
				FieldName,,Cancel);
			Return;
		EndIf;
		
		If Not Users.IsFullUser(InfobaseUser, True) Then
			CommonClientServer.MessageToUser(NStr("ru = 'У пользователя нет административных прав.'; en = 'This user has no administrative rights.'; pl = 'Użytkownik nie ma uprawnień administracyjnych.';es_ES = 'Usuario no tiene derechos administrativos.';es_CO = 'Usuario no tiene derechos administrativos.';tr = 'Kullanıcının yönetici hakları yok.';it = 'Questo utente non ha permessi di amministratore.';de = 'Der Benutzer hat keine administrativen Rechte.'"),,
				FieldName,,Cancel);
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ConnectionTypeOnChange(Item)
	
	Items.ConnectionTypeGroup.CurrentPage = ?(ConnectionType = "COM", Items.COMGroup, Items.RASGroup);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Write(Command)
	
	ClearMessages();
	
	If Not CheckFillingAtServer() Then
		Return;
	EndIf;
	
	// Filling the settings structure.
	FillPropertyValues(AdministrationParameters, ThisObject);
	
	CheckAdministrationParameters(AdministrationParameters);
	
	SaveConnectionParameters();
	
	// Restoring the password values.
	FillPropertyValues(AdministrationParameters, ThisObject);
	
	Close(AdministrationParameters);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServer
Function CheckFillingAtServer()
	
	Return CheckFilling();
	
EndFunction

&AtServer
Procedure SaveConnectionParameters()
	
	// Saving the parameters to a constant, clearing the passwords.
	StandardSubsystemsServer.SetAdministrationParameters(AdministrationParameters);
	
EndProcedure

&AtServer
Procedure GetIBAdministrator(InfobaseUser = Undefined)
	
	If Common.SeparatedDataUsageAvailable() Then
		
		If ValueIsFilled(IBAdministrator) Then
			
			InfobaseUser = InfoBaseUsers.FindByUUID(
				IBAdministrator.IBUserID);
			
		Else
			
			InfobaseUser = Undefined;
			
		EndIf;
		
		InfobaseAdministratorName = ?(InfobaseUser = Undefined, "", InfobaseUser.Name);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckAdministrationParameters(AdministrationParameters)
	
	If ConnectionType = "COM" Then
		CommonClient.RegisterCOMConnector(False);
	EndIf;
	
	If CommonClient.FileInfobase() Then
		
		ValidateFileInfobaseAdministrationParameters();
		
	Else
		
		If CommonClient.ClientConnectedOverWebServer() Then
			
			ValidateAdministrationParametersAtServer();
			
		Else
			ClusterAdministrationClientServer.CheckAdministrationParameters(AdministrationParameters,,
				Parameters.PromptForClusterAdministrationParameters, Parameters.PromptForIBAdministrationParameters);
		EndIf;
			
	EndIf;
	
EndProcedure

&AtServer
Procedure ValidateAdministrationParametersAtServer()
	
	ClusterAdministrationClientServer.CheckAdministrationParameters(AdministrationParameters,,
		Parameters.PromptForClusterAdministrationParameters, Parameters.PromptForIBAdministrationParameters);
	
EndProcedure

&AtServer
Procedure IsNecessaryToInputAdministrationParameters()
	
	AdministrationParametersInputRequired = True;
	
	If Parameters.PromptForIBAdministrationParameters AND Not Parameters.PromptForClusterAdministrationParameters Then
		
		UsersCount = InfoBaseUsers.GetUsers().Count();
		
		If UsersCount > 0 Then
			
			// Determining the actual user name even if it has been changed in the current session;
			// For example, to connect to the current infobase through an external connection from this session;
			// In all other cases, getting InfobaseUsers.CurrentUser() is sufficient.
			CurrentUser = InfoBaseUsers.FindByUUID(
				InfoBaseUsers.CurrentUser().UUID);
			
			If CurrentUser = Undefined Then
				CurrentUser = InfoBaseUsers.CurrentUser();
			EndIf;
			
			If CurrentUser.StandardAuthentication AND Not CurrentUser.PasswordIsSet 
				AND Users.IsFullUser(CurrentUser, True) Then
				
				AdministrationParameters.InfobaseAdministratorName = CurrentUser.Name;
				AdministrationParameters.InfobaseAdministratorPassword = "";
				
				AdministrationParametersInputRequired = False;
				
			EndIf;
			
		ElsIf UsersCount = 0 Then
			
			AdministrationParameters.InfobaseAdministratorName = "";
			AdministrationParameters.InfobaseAdministratorPassword = "";
			
			AdministrationParametersInputRequired = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ValidateFileInfobaseAdministrationParameters()
	
	If Parameters.PromptForIBAdministrationParameters Then
		
		// Connection check is not performed for the base versions.
		ClientRunParameters = StandardSubsystemsClient.ClientRunParameters();
		
		If ClientRunParameters.IsBaseConfigurationVersion
			Or ClientRunParameters.IsTrainingPlatform Then
			Return;
		EndIf;
		
		ConnectionParameters = CommonClientServer.ParametersStructureForExternalConnection();
		ConnectionParameters.InfobaseDirectory = StrSplit(InfoBaseConnectionString(), """")[1];
		ConnectionParameters.UserName = InfobaseAdministratorName;
		ConnectionParameters.UserPassword = InfobaseAdministratorPassword;
		
		Result = CommonClientServer.EstablishExternalConnectionWithInfobase(ConnectionParameters);
		
		If Result.Connection = Undefined Then
			
			Raise Result.BriefErrorDescription;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion