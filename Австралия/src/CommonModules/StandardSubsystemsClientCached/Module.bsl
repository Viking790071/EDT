#Region Private

// See StandardSubsystemsClient.ClientParametersOnStart(). 
Function ClientParametersOnStart() Export
	
	CheckStartProcedureBeforeStart();
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationRunParameters"];
	
	Parameters = New Structure;
	Parameters.Insert("RetrievedClientParameters", Undefined);
	
	If ApplicationStartParameters.Property("RetrievedClientParameters")
	   AND TypeOf(ApplicationStartParameters.RetrievedClientParameters) = Type("Structure") Then
		
		Parameters.Insert("RetrievedClientParameters",
			ApplicationStartParameters.RetrievedClientParameters);
	EndIf;
	
	If ApplicationStartParameters.Property("SkipClearingDesktopHiding") Then
		Parameters.Insert("SkipClearingDesktopHiding");
	EndIf;
	
	#If WebClient Then
		IsWebClient = True;
		IsMobileClient = False;
		ApplicationDirectory = "";
	#ElsIf MobileClient Then
		IsWebClient = False;
		IsMobileClient = True;
		ApplicationDirectory = "";
	#Else
		IsWebClient = False;
		IsMobileClient = False;
		ApplicationDirectory = BinDir();
	#EndIf
	
	ClientUsed = "";
	#If ThinClient Then
		ClientUsed = "ThinClient";
	#ElsIf ThickClientManagedApplication Then
		ClientUsed = "ThickClientManagedApplication";
	#ElsIf ThickClientOrdinaryApplication Then
		ClientUsed = "ThickClientOrdinaryApplication";
	#ElsIf WebClient Then
		BrowserDetails = CurrentBrowser();
		If IsBlankString(BrowserDetails.Version) Then
			ClientUsed = StringFunctionsClientServer.SubstituteParametersToString("WebClient.%1", BrowserDetails.Name);
		Else
			ClientUsed = StringFunctionsClientServer.SubstituteParametersToString("WebClient.%1.%2", BrowserDetails.Name, StrSplit(BrowserDetails.Version, ".")[0]);
		EndIf;
	#EndIf
	
	SystemInfo = New SystemInfo;
	IsLinuxClient = SystemInfo.PlatformType = PlatformType.Linux_x86
		Or SystemInfo.PlatformType = PlatformType.Linux_x86_64;
	IsOSXClient = SystemInfo.PlatformType = PlatformType.MacOS_x86
		Or SystemInfo.PlatformType = PlatformType.MacOS_x86_64;
	IsWindowsClient = SystemInfo.PlatformType = PlatformType.Windows_x86
		Or SystemInfo.PlatformType = PlatformType.Windows_x86_64;
	
	Parameters.Insert("LaunchParameter",      LaunchParameter);
	Parameters.Insert("InfobaseConnectionString", InfoBaseConnectionString());
	Parameters.Insert("IsWebClient",         IsWebClient);
	Parameters.Insert("IsMacOSWebClient", CommonClientCached.IsMacOSWebClient());
	Parameters.Insert("IsLinuxClient",       IsLinuxClient);
	Parameters.Insert("IsOSXClient",         IsOSXClient);
	Parameters.Insert("IsWindowsClient",     IsWindowsClient);
	Parameters.Insert("IsMobileClient",   IsMobileClient);
	Parameters.Insert("ClientUsed",   ClientUsed);
	Parameters.Insert("ApplicationDirectory",     ApplicationDirectory);
	Parameters.Insert("ClientID", SystemInfo.ClientID);
	Parameters.Insert("HideDesktopOnStart", False);
	
	SystemInfo = New SystemInfo;
	RAM = Round(SystemInfo.RAM / 1024, 1);
	Parameters.Insert("RAM", RAM);
	
	ClientScreenInfo = GetClientDisplaysInformation();
	If ClientScreenInfo.Count() > 0 Then
		DPI = ClientScreenInfo[0].DPI;
		Parameters.Insert("MainDisplayResolution", ?(DPI = 0, 72, DPI));
	Else
		Parameters.Insert("MainDisplayResolution", 72);
	EndIf;
	
	// Setting client's date before the call, in order to reduce the error limit.
	Parameters.Insert("CurrentDateOnClient", CurrentDate()); // To calculate SessionTimeOffset.
	Parameters.Insert("CurrentUniversalDateInMillisecondsOnClient",
		CurrentUniversalDateInMilliseconds());
	
	ClientParameters = StandardSubsystemsServerCall.ClientParametersOnStart(Parameters);
	
	If ApplicationStartParameters.Property("RetrievedClientParameters")
	   AND ApplicationStartParameters.RetrievedClientParameters <> Undefined
	   AND Not ApplicationStartParameters.Property("InterfaceOptions") Then
		
		ApplicationStartParameters.Insert("InterfaceOptions", ClientParameters.InterfaceOptions);
		ApplicationStartParameters.RetrievedClientParameters.Insert("InterfaceOptions");
	EndIf;
	
	StandardSubsystemsClient.FillClientParameters(ClientParameters);
	
	// Updating the desktop hiding status on client by the state on server.
	StandardSubsystemsClient.HideDesktopOnStart(
		Parameters.HideDesktopOnStart, True);
	
	Return ClientParameters;
	
EndFunction

// See StandardSubsystemsClient.ClientRunParameters(). 
Function ClientRunParameters() Export
	
	CheckStartProcedureBeforeStart();
	CheckStartProcedureOnStart();
	
	ClientProperties = New Structure;
	
	// Setting client's date before the call, in order to reduce the error limit.
	ClientProperties.Insert("CurrentDateOnClient", CurrentDate()); // To calculate SessionTimeOffset.
	ClientProperties.Insert("CurrentUniversalDateInMillisecondsOnClient",
		CurrentUniversalDateInMilliseconds());
	
	Return StandardSubsystemsServerCall.ClientRunParameters(ClientProperties);
	
EndFunction

Procedure CheckStartProcedureBeforeStart()
	
	ParameterName = "StandardSubsystems.ApplicationStartCompleted";
	If ApplicationParameters[ParameterName] = Undefined Then
		Raise
			NStr("ru = 'Ошибка порядка запуска программы.
			           |Первой процедурой, которая вызывается из обработчика события BeforeStart
			           |должна быть процедура БСП StandardSubsystemsClient.BeforeStart.'; 
			           |en = 'Application startup sequence error.
			           |In the BeforeStart event handler,
			           |the first procedure call must be StandardSubsystemsClient.BeforeStart.'; 
			           |pl = 'Błąd kolejności uruchamiania programu.
			           |W programie obsługi wydarzenia BeforeStart,
			           |musi być wywołana pierwsza procedura StandardSubsystemsClient.BeforeStart.';
			           |es_ES = 'Error de orden de lanzar el programa.
			           |El primer procedimiento que se llama del procesador del evento BeforeStart
			           | debe ser el procedimiento StandardSubsystemsClient.BeforeStart.';
			           |es_CO = 'Error de orden de lanzar el programa.
			           |El primer procedimiento que se llama del procesador del evento BeforeStart
			           | debe ser el procedimiento StandardSubsystemsClient.BeforeStart.';
			           |tr = 'Uygulama başlatma düzeninin hatası.
			           |BeforeStart olay işleyicisinden çağrılan ilk prosedür, StandardSubsystemsClient.BeforeStart prosedürü 
			           |olmalıdır.';
			           |it = 'Errore nella sequenza di avvio dell''applicazione.
			           |La prima procedura
			           |che deve essere chiamata nel gestore di eventi BeforStart è la StandardSubsystemsClient.BeforeStart.';
			           |de = 'Fehler bei der Programmstartreihenfolge.
			           |Die erste Prozedur, die aus dem Eventhandler VorDemSystemstart aufgerufen wird,
			           |sollte die Prozedur BSP StandardSubsystemClient.VorDemSystemstart'");
	EndIf;
	
EndProcedure

Procedure CheckStartProcedureOnStart()
	
	If Not StandardSubsystemsClient.ApplicationStartCompleted() Then
		Raise
			NStr("ru = 'Ошибка порядка запуска программы.
			           |Перед получением параметров работы клиента запуск программы должен быть завершен.'; 
			           |en = 'Application startup sequence error.
			           |Application startup must be completed before getting the client parameters.'; 
			           |pl = 'Błąd kolejności uruchamiania programu. 
			           |Przed uzyskaniem parametrów pracy klienta uruchomienie programu powinno być zakończone.';
			           |es_ES = 'Error de orden de lanzar el programa.
			           |Antes de recibir los parámetros del funcionamiento del cliente el lanzamiento del programa debe ser terminado.';
			           |es_CO = 'Error de orden de lanzar el programa.
			           |Antes de recibir los parámetros del funcionamiento del cliente el lanzamiento del programa debe ser terminado.';
			           |tr = 'Uygulama başlatma düzeninin hatası. 
			           |İstemci çalışma ayarlarını almadan önce, programın çalıştırılması tamamlanmalıdır.';
			           |it = 'Errore nell''ordine di avvio del programma.
			           |Prima di ricevere i parametri del client, è necessario completare l''avvio del programma.';
			           |de = 'Fehler beim Programmstartreihenfolge.
			           |Bevor Sie die Client-Betriebsparameter empfangen, muss der Programmstart abgeschlossen sein.'");
	EndIf;
	
EndProcedure

Function CurrentBrowser()
	
	Result = New Structure("Name,Version", "Other", "");
	
	SystemInfo = New SystemInfo;
	Row = SystemInfo.UserAgentInformation;
	Row = StrReplace(Row, ",", ";");

	// Opera
	ID = "Opera";
	Position = StrFind(Row, ID, SearchDirection.FromEnd);
	If Position > 0 Then
		Row = Mid(Row, Position + StrLen(ID));
		Result.Name = "Opera";
		ID = "Version/";
		Position = StrFind(Row, ID);
		If Position > 0 Then
			Row = Mid(Row, Position + StrLen(ID));
			Result.Version = TrimAll(Row);
		Else
			Row = TrimAll(Row);
			If StrStartsWith(Row, "/") Then
				Row = Mid(Row, 2);
			EndIf;
			Result.Version = TrimL(Row);
		EndIf;
		Return Result;
	EndIf;

	// IE
	ID = "MSIE"; // v11-
	Position = StrFind(Row, ID);
	If Position > 0 Then
		Result.Name = "IE";
		Row = Mid(Row, Position + StrLen(ID));
		Position = StrFind(Row, ";");
		If Position > 0 Then
			Row = TrimL(Left(Row, Position - 1));
			Result.Version = Row;
		EndIf;
		Return Result;
	EndIf;

	ID = "Trident"; // v11+
	Position = StrFind(Row, ID);
	If Position > 0 Then
		Result.Name = "IE";
		Row = Mid(Row, Position + StrLen(ID));
		
		ID = "rv:";
		Position = StrFind(Row, ID);
		If Position > 0 Then
			Row = Mid(Row, Position + StrLen(ID));
			Position = StrFind(Row, ")");
			If Position > 0 Then
				Row = TrimL(Left(Row, Position - 1));
				Result.Version = Row;
			EndIf;
		EndIf;
		Return Result;
	EndIf;

	// Chrome
	ID = "Chrome/";
	Position = StrFind(Row, ID);
	If Position > 0 Then
		Result.Name = "Chrome";
		Row = Mid(Row, Position + StrLen(ID));
		Position = StrFind(Row, " ");
		If Position > 0 Then
			Row = TrimL(Left(Row, Position - 1));
			Result.Version = Row;
		EndIf;
		Return Result;
	EndIf;

	// Safari
	ID = "Safari/";
	If StrFind(Row, ID) > 0 Then
		Result.Name = "Safari";
		ID = "Version/";
		Position = StrFind(Row, ID);
		If Position > 0 Then
			Row = Mid(Row, Position + StrLen(ID));
			Position = StrFind(Row, " ");
			If Position > 0 Then
				Result.Version = TrimAll(Left(Row, Position - 1));
			EndIf;
		EndIf;
		Return Result;
	EndIf;

	// Firefox
	ID = "Firefox/";
	Position = StrFind(Row, ID);
	If Position > 0 Then
		Result.Name = "Firefox";
		Row = Mid(Row, Position + StrLen(ID));
		If Not IsBlankString(Row) Then
			Result.Version = TrimAll(Row);
		EndIf;
		Return Result;
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Predefined data processing.

// See StandardSubsystemsCached.RefsByPredefinedItemsNames 
Function RefsByPredefinedItemsNames(FullMetadataObjectName) Export
	
	Return StandardSubsystemsServerCall.RefsByPredefinedItemsNames(FullMetadataObjectName);
	
EndFunction

#EndRegion
