////////////////////////////////////////////////////////////////////////////////
// Client procedures and functions of common use:
//  
////////////////////////////////////////////////////////////////////////////////

#Region Internal

// Checks whether the passed string is an internal URL.
//  
// Parameters:
//  String - String - URL.
//
Function IsURL(Row) Export
	
	Return StrStartsWith(Row, "e1c:")
		Or StrStartsWith(Row, "e1cib/");
	
EndFunction

// Parameters:
//  Context - Structure - procedure context:
//      * Notification - NotifyDescription - .
//      * ID - String - 
//      * Location - String - 
//      * Cached - Boolean -
//      * SuggestInstall - Boolean -.
//      * NoteText - String - .
//      * ObjectsCreationIDs
//
Procedure AttachAddInSSL(Context) Export
	
	If IsBlankString(Context.ID) Then 
		AddInContainsOneObjectClass = (Context.ObjectCreationIDs.Count() = 0);
		
		If AddInContainsOneObjectClass Then 
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось подключить внешнюю компоненту на клиенте
				           |%1
				           |по причине:
				           |Не допустимо одновременно не указывать и ID и ObjectCreationIDs'; 
				           |en = 'Cannot attach the add-in on the client
				           |%1
				           |Reason:
				           |Either the ID or the ObjectCreationIDs must be specified.'; 
				           |pl = 'Podłączenie do komponentu zewnętrznego nie powiodło się dla klienta
				           |%1
				           |z powodu:
				           |Nie dopuszczalne jest jednocześnie nie wskazywać i ID i ObjectCreationIDs';
				           |es_ES = 'No se ha podido conectar el componente externo en el cliente
				           |%1
				           |a causa de:
				           |Se debe especificar el ID o los ObjectCreationIDs.';
				           |es_CO = 'No se ha podido conectar el componente externo en el cliente
				           |%1
				           |a causa de:
				           |Se debe especificar el ID o los ObjectCreationIDs.';
				           |tr = 'Dış bileşen 
				           |%1
				           |istemcide aşağıdaki nedenle bağlanamadı: 
				           | Tanımlayıcının ve ObjectCreationIDs aynı anda belirtilmesine izin verilmez';
				           |it = 'Impossibile allegare la componente aggiuntiva al client
				           |%1
				           |Motivo:
				           |deve essere indicata l''ID o ObjectCreationIDs.';
				           |de = 'Addin konnte nicht mit dem Client
				           |%1
				           |aus folgendem Grund :
				           | verbunden werden. Entweder ID oder ObjectCreationIDs soll angegeben werden.'"), 
				Context.Location);
		Else
			// In case when the add in contains several classes of objects.
			// An ID is used only to display the add in in the texts of errors.
			// Collect the ID to display.
			Context.ID = StrConcat(Context.ObjectCreationIDs, ", ");
		EndIf;
	EndIf;
	
	If Not ValidAddInLocation(Context.Location) Then 
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось подключить внешнюю компоненту ""%1"" на клиенте
			           |%2
			           |по причине:
			           |Не допустимо подключить компоненты из указанного местоположения.'; 
			           |en = 'Cannot attach add-in ""%1"" on the client
			           |%2
			           |Reason:
			           |Attaching add-ins from this location is not allowed.'; 
			           |pl = 'Podłączenie do komponentu zewnętrznego nie powiodło się ""%1"" dla klienta
			           |%2
			           |z powodu:
			           |Nie dopuszczalne jest podłączenie komponentów ze wskazanej lokalizacji.';
			           |es_ES = 'No se ha podido conectar un componente externo ""%1"" en el cliente 
			           |%2
			           |a causa de:
			           |No se admite conectar los componentes de la ubicación indicada.';
			           |es_CO = 'No se ha podido conectar un componente externo ""%1"" en el cliente 
			           |%2
			           |a causa de:
			           |No se admite conectar los componentes de la ubicación indicada.';
			           |tr = 'Harici bileşen ""%1"" istemcide aşağıdaki nedenle 
			           |%2
			           |bağlanamadı: 
			           |bileşenlerin belirtilen konumdan bağlanmasına izin verilmez.';
			           |it = 'Impossibile allegare componente aggiuntiva ""%1"" al client
			           |%2
			           |Motivo:
			           |Non è permesso allegare componenti aggiuntive da questa posizione.';
			           |de = 'Eine externe Komponente ""%1"" konnte auf dem Client
			           |%2
			           |nicht verbunden werden, da:
			           |Es ist nicht erlaubt, Komponenten vom angegebenen Standort aus zu verbinden.'"), 
			Context.ID,
			Context.Location);
	EndIf;
	
	If Context.Cached Then 
		
		AttachableModule = GetAddInObjectFromCache(Context.Location);
		If AttachableModule <> Undefined Then 
			AttachAddInSSLNotifyOnAttachment(AttachableModule, Context);
			Return;
		EndIf;
		
	EndIf;
	
	// Checking the connection of the external add in in this session earlier.
	SymbolicName = GetAddInSymbolicNameFromCache(Context.Location);
	
	If SymbolicName = Undefined Then 
		
		// Generating a unique name.
		SymbolicName = "From" + StrReplace(String(New UUID), "-", "");
		
		Context.Insert("SymbolicName", SymbolicName);
		
		Notification = New NotifyDescription(
			"AttachAddInSSLAfterAttachmentAttempt", ThisObject, Context,
			"AttachAddInSSLOnProcessError", ThisObject);
		
		BeginAttachingAddIn(Notification, Context.Location, SymbolicName);
		
	Else 
		
		// If the cache already has a symbolic name, it means that the add-in has already been attached to this session.
		Attached = True;
		Context.Insert("SymbolicName", SymbolicName);
		AttachAddInSSLAfterAttachmentAttempt(Attached, Context);
		
	EndIf;
	
EndProcedure

// Continue the AttachAddInSSL procedure.
Procedure AttachAddInSSLNotifyOnAttachment(AttachableModule, Context) Export
	
	Notification = Context.Notification;
	
	Result = AddInAttachmentResult();
	Result.Attached = True;
	Result.AttachableModule = AttachableModule;
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure

// Continue the AttachAddInSSL procedure.
Procedure AttachAddInSSLNotifyOnError(ErrorDescription, Context) Export
	
	Notification = Context.Notification;
	
	Result = AddInAttachmentResult();
	Result.ErrorDescription = ErrorDescription;
	ExecuteNotifyProcessing(Notification, Result);
	
EndProcedure

// Parameters:
//  Context - Structure - procedure context:
//      * Notification - NotifyDescription - .
//      * Location - String -
//      * NoteText - String - .
//
Procedure InstallAddInSSL(Context) Export
	
	If Not ValidAddInLocation(Context.Location) Then 
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось установить внешнюю компоненту ""%1"" на клиенте
			           |%2
			           |по причине:
			           |Не допустимо устанавливать компоненты из указанного местоположения.'; 
			           |en = 'Cannot install add-in ""%1"" on the client
			           |%2
			           |Reason:
			           |Installing add-ins from this location is not allowed.'; 
			           |pl = 'Nie udało się ustawić komponent zewnętrzny ""%1"" dla klienta
			           |%2
			           |z powodu:
			           |Nie dopuszczalne jest ustawienie komponentu ze wskazanej lokalizacji.';
			           |es_ES = 'No se ha podido instalar un componente externo ""%1"" en el cliente 
			           |%2
			           |a causa de:
			           |No se admite instalar los componentes de la ubicación indicada.';
			           |es_CO = 'No se ha podido instalar un componente externo ""%1"" en el cliente 
			           |%2
			           |a causa de:
			           |No se admite instalar los componentes de la ubicación indicada.';
			           |tr = 'Harici bileşen ""%1"" istemcide aşağıdaki nedenle 
			           |%2
			           |bağlanamadı: 
			           |bileşenlerin belirtilen konumdan bağlanmasına izin verilmez.';
			           |it = 'Impossibile connettere la componente esterna ""%1"" sul client
			           |%2
			           |a causa di:
			           | Non è consentito installare componenti dalla posizione specificata.';
			           |de = 'Die externe Komponente ""%1"" konnte auf dem Client
			           |%2
			           |aus folgendem Grund nicht installiert werden:
			           |Es ist nicht erlaubt, Komponenten vom angegebenen Ort aus zu installieren.'"), 
			Context.ID,
			Context.Location);
	EndIf;
	
	// Checking the connection of the external add in in this session earlier.
	SymbolicName = GetAddInSymbolicNameFromCache(Context.Location);
	
	If SymbolicName = Undefined Then
		
		Notification = New NotifyDescription(
			"InstallAddInSSLAfterAnswerToInstallationQuestion", ThisObject, Context);
		
		FormParameters = New Structure;
		FormParameters.Insert("NoteText", Context.NoteText);
		
		OpenForm("CommonForm.AddInInstallationQuestion", 
			FormParameters,,,,, Notification);
		
	Else 
		
		// If the cache already has a symbolic name, it means that the add-in has already been attached to 
		// this session and it means that the external add-in is installed.
		Result = AddInInstallationResult();
		Result.Insert("Installed", True);
		ExecuteNotifyProcessing(Context.Notification, Result);
		
	EndIf;
	
EndProcedure

// Continue the InstallAddInSSL procedure.
Procedure InstallAddInSSLNotifyOnError(ErrorDescription, Context) Export
	
	Notification = Context.Notification;
	
	Result = AddInInstallationResult();
	Result.ErrorDescription = ErrorDescription;
	ExecuteNotifyProcessing(Notification, Result);
	
EndProcedure

#EndRegion

#Region Private

#Region AddIns

#Region AttachAddIn

// Continue the AttachAddInSSL procedure.
Procedure AttachAddInSSLAfterAttachmentAttempt(Attached, Context) Export 
	
	If Attached Then 
		
		// Saving the fact of attaching the external add-in to this session.
		WriteAddInSymbolicNameToCache(Context.Location, Context.SymbolicName);
		
		AttachableModule = Undefined;
		
		Try
			AttachableModule = NewAddInObject(Context);
		Except
			// The error text has already been composed to the NewAddInObject, you just need to notify.
			ErrorText = BriefErrorDescription(ErrorInfo());
			AttachAddInSSLNotifyOnError(ErrorText, Context);
			Return;
		EndTry;
		
		If Context.Cached Then 
			WriteAddInObjectToCache(Context.Location, AttachableModule)
		EndIf;
		
		AttachAddInSSLNotifyOnAttachment(AttachableModule, Context);
		
	Else 
		
		If Context.SuggestInstall Then 
			AttachAddInSSLStartInstallation(Context);
		Else 
			ErrorText =  StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось подключить внешнюю компоненту ""%1"" на клиенте
				           |%2
				           |по причине:
				           |Метод BeginAttachingAddIn вернул False.'; 
				           |en = 'Cannot attach add-in ""%1"" on the client
				           |%2
				           |Reason:
				           |Method BeginAttachingAddIn returned False.'; 
				           |pl = 'Podłączenie do komponentu zewnętrznego nie powiodło się ""%1"" dla klienta
				           |%2
				           |z powodu:
				           |Metoda BeginAttachingAddIn wrócił False.';
				           |es_ES = 'No se ha podido conectar un componente externo ""%1"" en el cliente
				           |de la plantilla ""%2""
				           |a causa de:
				           |Método BeginAttachingAddIn ha devuelto False.';
				           |es_CO = 'No se ha podido conectar un componente externo ""%1"" en el cliente
				           |de la plantilla ""%2""
				           |a causa de:
				           |Método BeginAttachingAddIn ha devuelto False.';
				           |tr = '
				           | istemcinin ""%1"" harici bileşeni ""%2""
				           | nedenle bağlanamadı: 
				           |Yöntem BeginAttachingAddIn iade etti False.';
				           |it = 'Impossibile allegare la componente aggiuntiva ""%1"" al client
				           |%2
				           |Motivo:
				           |il metodo BeginAttachingAddIn restituisce False.';
				           |de = 'Die externe Komponente ""%1"" konnte aus folgendem Grund nicht auf dem Client
				           |%2
				           |verbunden werden:
				           |Methode StartVerbindungExterneKomponenten gaben False zurück.'"),
				Context.ID,
				AddInLocationPresentation(Context.Location));
			
			AttachAddInSSLNotifyOnError(ErrorText, Context);
		EndIf;
		
	EndIf;
	
EndProcedure

// Continue the AttachAddInSSL procedure.
Procedure AttachAddInSSLStartInstallation(Context)
	
	Notification = New NotifyDescription(
		"AttachAddInSSLAfterInstallation", ThisObject, Context);
	
	InstallationContext = New Structure;
	InstallationContext.Insert("Notification", Notification);
	InstallationContext.Insert("Location", Context.Location);
	InstallationContext.Insert("NoteText", Context.NoteText);
	
	InstallAddInSSL(InstallationContext);
	
EndProcedure

// Continue the AttachAddInSSL procedure.
Procedure AttachAddInSSLAfterInstallation(Result, Context) Export 
	
	If Result.Installed Then 
		// One attempt to install has already passed, if the component does not connect this time, do not 
		// offer to install it again.
		Context.SuggestInstall = False;
		AttachAddInSSL(Context);
	Else 
		// Adding details to ErrorDescription is not required as the text has already been generated during the installation.
		// If a user canceled the installation, ErrorDescription is a blank string.
		AttachAddInSSLNotifyOnError(Result.ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continue the AttachAddInSSL procedure.
Procedure AttachAddInSSLOnProcessError(ErrorInformation, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Не удалось подключить внешнюю компоненту ""%1"" на клиенте
		           |%2
		           |по причине:
		           |%3'; 
		           |en = 'Cannot attach add-in ""%1"" on the client
		           |%2
		           |Reason:
		           |%3'; 
		           |pl = 'Podłączenie do komponentu zewnętrznego nie powiodło się ""%1"" dla klienta
		           |%2
		           |z powodu:
		           |%3';
		           |es_ES = 'No se ha podido conectar un componente externo ""%1"" en el cliente
		           |%2
		           |a causa de:
		           |%3';
		           |es_CO = 'No se ha podido conectar un componente externo ""%1"" en el cliente
		           |%2
		           |a causa de:
		           |%3';
		           |tr = '
		           | istemcinin ""%1"" harici bileşeni ""%2""
		           | nedenle bağlanamadı: 
		           |%3';
		           |it = 'Impossibile connettere la componente esterna ""%1"" sul client
		           |%2
		           |a causa di:
		           |%3';
		           |de = 'Eine externe Komponente ""%1"" konnte aus diesem Grund auf dem Client
		           |%2
		           |nicht angeschlossen werden:
		           |%3'"),
		Context.ID,
		AddInLocationPresentation(Context.Location),
		BriefErrorDescription(ErrorInformation));
		
	AttachAddInSSLNotifyOnError(ErrorText, Context);
	
EndProcedure

// Creates an instance of external component (or a couple of instances)
Function NewAddInObject(Context)
	
	AddInContainsOneObjectClass = (Context.ObjectCreationIDs.Count() = 0);
	
	If AddInContainsOneObjectClass Then 
		
		Try
			AttachableModule = New("AddIn." + Context.SymbolicName + "." + Context.ID);
			If AttachableModule = Undefined Then 
				Raise NStr("ru = 'Оператор Новый вернул Неопределено'; en = 'The New operator returned Undefined.'; pl = 'Operator Nowy zwrócił Nieokreślone';es_ES = 'Operador Nuevo ha devuelto No determinado';es_CO = 'Operador Nuevo ha devuelto No determinado';tr = 'Operatör Yeni iade etti Belirsiz';it = 'Il nuovo operatore sarà restituito indefinito.';de = 'Operator Neu zurückgegeben Undefiniert'");
			EndIf;
		Except
			AttachableModule = Undefined;
			ErrorText = BriefErrorDescription(ErrorInfo());
		EndTry;
		
		If AttachableModule = Undefined Then 
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось создать объект внешней компоненты ""%1"", подключенной на клиенте
				           |%2,
				           |по причине:
				           |%3'; 
				           |en = 'Cannot create an object for add-in ""%1"" attached on the client
				           |%2
				           |Reason:
				           |%3'; 
				           |pl = 'Nie udało się utworzyć obiekt komponentów zewnętrznych ""%1"", podłączonych dla klienta
				           |%2,
				           |z powodu:
				           |%3';
				           |es_ES = 'No se ha podido crear un objeto del componente externo ""%1"" conectado en el cliente
				           |%2
				           |a causa de:
				           |%3';
				           |es_CO = 'No se ha podido crear un objeto del componente externo ""%1"" conectado en el cliente
				           |%2
				           |a causa de:
				           |%3';
				           |tr = '%1 sunucuda bağlanan "
" harici bileşenin nesnesi ""%2"" oluşturulamadı, 
				           | nedeni: 
				           |%3';
				           |it = 'Non è stato possibile creare l''oggetto della componente esterna ""%1"", attiva sul client
				           |%2,
				           |a causa di:
				           |%3';
				           |de = 'Es war nicht möglich, ein Objekt der externen Komponente ""%1"" zu erstellen, das mit dem Client
				           |%2
				           |verbunden ist, aus folgendem Grund:
				           |%3'"),
				Context.ID,
				AddInLocationPresentation(Context.Location),
				ErrorText);
			
		EndIf;
		
	Else 
		
		AttachableModules = New Map;
		For each ObjectID In Context.ObjectCreationIDs Do 
			
			Try
				AttachableModule = New("AddIn." + Context.SymbolicName + "." + ObjectID);
				If AttachableModule = Undefined Then 
					Raise NStr("ru = 'Оператор Новый вернул Неопределено'; en = 'The New operator returned Undefined.'; pl = 'Operator Nowy zwrócił Nieokreślone';es_ES = 'Operador Nuevo ha devuelto No determinado';es_CO = 'Operador Nuevo ha devuelto No determinado';tr = 'Operatör Yeni iade etti Belirsiz';it = 'Il nuovo operatore sarà restituito indefinito.';de = 'Operator Neu zurückgegeben Undefiniert'");
				EndIf;
			Except
				AttachableModule = Undefined;
				ErrorText = BriefErrorDescription(ErrorInfo());
			EndTry;
			
			If AttachableModule = Undefined Then 
				
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Не удалось создать объект ""%1"" внешней компоненты ""%2"", подключенной на клиенте
					           |%3,
					           |по причине:
					           |%4'; 
					           |en = 'Cannot create object ""%1"" for add-in ""%2"" attached on the client
					           |%3
					           |Reason:
					           |%4'; 
					           |pl = 'Nie udało się utworzyć obiekt ""%1"" komponentów zewnętrznych ""%2"", jest podłączonych dla klienta
					           |%3,
					           |z powodu:
					           |%4';
					           |es_ES = 'No se ha podido crear un objeto ""%1"" del componente externo ""%2"" conectado en el cliente
					           |%3
					           |a causa de:
					           |%4';
					           |es_CO = 'No se ha podido crear un objeto ""%1"" del componente externo ""%2"" conectado en el cliente
					           |%3
					           |a causa de:
					           |%4';
					           |tr = 'Sunucuda bağlanan ""%2"" harici bileşenin nesnesi ""%1"" oluşturulamadı, 
					           |%3
					           | Nedeni:
					           |%4';
					           |it = 'Non è stato possibile creare l''oggetto ""%1"" della componente esterna ""%2"", attiva sul client
					           |%3,
					           |a causa di:
					           |%4';
					           |de = 'Das Objekt ""%1"" der mit dem Client
					           |%3 verbundenen externen Komponente ""%2"" konnte aus
					           |folgendem Grund nicht erstellt werden:
					           |%4'"),
					ObjectID,
					Context.ID,
					AddInLocationPresentation(Context.Location),
					ErrorText);
				
			EndIf;
			
			AttachableModules.Insert(ObjectID, AttachableModule);
			
		EndDo;
		
		AttachableModule = New FixedMap(AttachableModules);
		
	EndIf;
	
	Return AttachableModule;
	
EndFunction

// Continue the AttachAddInSSL procedure.
Function AddInAttachmentResult()
	
	Result = New Structure;
	Result.Insert("Attached", False);
	Result.Insert("ErrorDescription", "");
	Result.Insert("AttachableModule", Undefined);
	
	Return Result;
	
EndFunction

// Continue the AttachAddInSSL procedure.
Function AddInLocationPresentation(Location)
	
	If StrStartsWith(Location, "e1cib/") Then
		Return NStr("ru = 'из хранилища внешних компонент'; en = 'from an external component storage.'; pl = 'z przechowywania komponentów zewnętrznych';es_ES = 'del almacenamiento de los componentes externos';es_CO = 'del almacenamiento de los componentes externos';tr = 'harici bileşenlerin deposundan';it = 'da un componente esterno archivio';de = 'aus dem Speicher externer Komponenten'");
	Else 
		Return StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'из макета ""%1""'; en = 'from template ""%1.""'; pl = 'z makiety ""%1""';es_ES = 'de la plantilla ""%1""';es_CO = 'de la plantilla ""%1""';tr = '""%1"" şablonundan';it = 'dal template ""%1"".';de = 'aus dem Modell ""%1""'"),
			Location);
	EndIf;
	
EndFunction

#EndRegion

#Region InstallAddIn

// Continue the InstallAddInSSL procedure.
Procedure InstallAddInSSLAfterAnswerToInstallationQuestion(Response, Context) Export
	
	// Result:
	// - DialogReturnCode.Yes - Install.
	// - DialogReturnCode.Cancel - Cancel
	// - Undefined - the dialog box is closed.
	If Response = DialogReturnCode.Yes Then
		InstallAddInSSLStartInstallation(Context);
	Else
		Result = AddInInstallationResult();
		ExecuteNotifyProcessing(Context.Notification, Result);
	EndIf;
	
EndProcedure

// Continue the InstallAddInSSL procedure.
Procedure InstallAddInSSLStartInstallation(Context)
	
	Notification = New NotifyDescription(
		"InstallAddInSSLAfterInstallationAttempt", ThisObject, Context,
		"InstallAddInSSLOnProcessError", ThisObject);
	
	BeginInstallAddIn(Notification, Context.Location);
	
EndProcedure

// Continue the InstallAddInSSL procedure.
Procedure InstallAddInSSLAfterInstallationAttempt(Context) Export 
	
	Result = AddInInstallationResult();
	Result.Insert("Installed", True);
	
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure

// Continue the InstallAddInSSL procedure.
Procedure InstallAddInSSLOnProcessError(ErrorInformation, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Не удалось установить внешнюю компоненту ""%1"" на клиенте 
		           |%2
		           |по причине:
		           |%3'; 
		           |en = 'Cannot install add-in ""%1"" on the client
		           |%2
		           |Reason:
		           |%3'; 
		           |pl = 'Nie udało się ustawić komponent zewnętrzny ""%1"" dla klienta 
		           |%2
		           |z powodu:
		           |%3';
		           |es_ES = 'No se ha podido instalar un componente externo ""%1"" en el cliente
		           |%2
		           |a causa de:
		           |%3';
		           |es_CO = 'No se ha podido instalar un componente externo ""%1"" en el cliente
		           |%2
		           |a causa de:
		           |%3';
		           |tr = '
		           | istemcinin ""%1"" harici bileşeni ""%2""
		           | nedenle bağlanamadı: 
		           |%3';
		           |it = 'Non è stato possibile ripristinare la componente esterna ""%1"" sul client 
		           |%2
		           |a causa di:
		           |%3';
		           |de = 'Eine externe Komponente ""%1"" konnte auf dem Client
		           |%2
		           |nicht installiert werden, wegen:
		           |%3'"),
		Context.ID,
		AddInLocationPresentation(Context.Location),
		BriefErrorDescription(ErrorInformation));
	
	Result = AddInInstallationResult();
	Result.ErrorDescription = ErrorText;
	
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure

// Continue the InstallAddInSSL procedure.
Function AddInInstallationResult()
	
	Result = New Structure;
	Result.Insert("Installed", False);
	Result.Insert("ErrorDescription", "");
	
	Return Result;
	
EndFunction

#EndRegion

// Check the correctness of add-in location.
Function ValidAddInLocation(Location)
	
	If CommonClient.SubsystemExists("StandardSubsystems.AddIns") Then
		ModuleAddInsInternalClient = CommonClient.CommonModule("AddInsInternalClient");
		If ModuleAddInsInternalClient.IsComponentFromStorage(Location) Then
			Return True;
		EndIf;
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.SaaS.AddInsSaaS") Then
		ModuleAddInsSaaSInternalClient = CommonClient.CommonModule("AddInsSaaSInternalClient");
		If ModuleAddInsSaaSInternalClient.IsComponentFromStorage(Location) Then
			Return True;
		EndIf;
	EndIf;
	
	Return IsTemplate(Location);
	
EndFunction

// Checks that the location indicates the add-in.
Function IsTemplate(Location)
	
	PathSteps = StrSplit(Location, ".");
	If PathSteps.Count() < 2 Then 
		Return False;
	EndIf;
	
	Path = New Structure;
	Try
		For each PathStep In PathSteps Do 
			Path.Insert(PathStep);
		EndDo;
	Except
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

// Gets the symbolic name of the external add-in from the cache, if it was previously attached.
Function GetAddInSymbolicNameFromCache(ObjectKey)
	
	SymbolicName = Undefined;
	CachedSymbolicNames = ApplicationParameters["StandardSubsystems.AddIns.SymbolicNames"];
	
	If TypeOf(CachedSymbolicNames) = Type("FixedMap") Then
		SymbolicName = CachedSymbolicNames.Get(ObjectKey);
	EndIf;
	
	Return SymbolicName;
	
EndFunction

// Writes the symbolic name of the external add-in to the cache.
Procedure WriteAddInSymbolicNameToCache(ObjectKey, SymbolicName)
	
	Map = New Map;
	CachedSymbolicNames = ApplicationParameters["StandardSubsystems.AddIns.SymbolicNames"];
	
	If TypeOf(CachedSymbolicNames) = Type("FixedMap") Then
		
		If CachedSymbolicNames.Get(ObjectKey) <> Undefined Then // It is already in the cache.
			Return;
		EndIf;
		
		For each Item In CachedSymbolicNames Do
			Map.Insert(Item.Key, Item.Value);
		EndDo;
		
	EndIf;
	
	Map.Insert(ObjectKey, SymbolicName);
	
	ApplicationParameters.Insert("StandardSubsystems.AddIns.SymbolicNames",
		New FixedMap(Map));
	
EndProcedure

// Receives an object that is an instance of the add-in from the cache.
Function GetAddInObjectFromCache(ObjectKey)
	
	AttachableModule = Undefined;
	CachedObjects = ApplicationParameters["StandardSubsystems.AddIns.Objects"];
	
	If TypeOf(CachedObjects) = Type("FixedMap") Then
		AttachableModule = CachedObjects.Get(ObjectKey);
	EndIf;
	
	Return AttachableModule;
	
EndFunction

// Writes the instance of the add-in to the cache.
Procedure WriteAddInObjectToCache(ObjectKey, AttachableModule)
	
	Map = New Map;
	CachedObjects = ApplicationParameters["StandardSubsystems.AddIns.Objects"];
	
	If TypeOf(CachedObjects) = Type("FixedMap") Then
		For each Item In CachedObjects Do
			Map.Insert(Item.Key, Item.Value);
		EndDo;
	EndIf;
	
	Map.Insert(ObjectKey, AttachableModule);
	
	ApplicationParameters.Insert("StandardSubsystems.AddIns.Objects",
		New FixedMap(Map));
	
EndProcedure

#EndRegion

#Region OpenExplorer

// Continue the CommonClient.OpenExplorer procedure.
Procedure OpenExplorerAfterCheckFileSystemExtension(ExtensionAttached, Context) Export
	
	FileInfo = Context.FileInfo;
	
	If ExtensionAttached Then
		Notification = New NotifyDescription(
			"OpenExplorerAfterCheckIfExists", ThisObject, Context, 
			"OpenExplorerOnProcessError", ThisObject);
		FileInfo.BeginCheckingExistence(Notification);
	Else
		ErrorDescription = NStr("ru = 'Расширение для работы с файлами не установлено, открытие папки не возможно.'; en = 'Cannot open the directory because the file system extension is not installed.'; pl = 'Rozszerzenie do pracy z plikami nie jest ustawione, otwarcie folderu jest niemożliwe.';es_ES = 'La extensión del uso de archivos no está instalada, no se puede abrir el catálogo.';es_CO = 'La extensión del uso de archivos no está instalada, no se puede abrir el catálogo.';tr = 'Dosya işlemi uzantısı yüklü değil, klasör açılamıyor.';it = 'Impossibile aprire la directory poiché l''estensione del file di sistema non è installata.';de = 'Die Erweiterung für das Arbeiten mit Dateien ist nicht installiert, das Öffnen eines Ordners ist nicht möglich.'");
		OpenExplorerNotifyOnError(ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continue the CommonClient.OpenExplorer procedure.
Procedure OpenExplorerAfterCheckIfExists(Exists, Context) Export 
	
	FileInfo = Context.FileInfo;
	
	If Exists Then 
		Notification = New NotifyDescription(
			"OpenExplorerAfterCheckIsFIle", ThisObject, Context, 
			"OpenExplorerOnProcessError", ThisObject);
		FileInfo.BeginCheckingIsFile(Notification);
	Else 
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не найдена папка, которую требуется открыть в проводнике:
			           |""%1""'; 
			           |en = 'Cannot find the directory to open in Explorer:
			           |""%1.""'; 
			           |pl = 'Nie wyszukano folder, który trzeba otworzyć w przewodniku:
			           |""%1""';
			           |es_ES = 'No se ha encontrado carpeta que se requiere abrir en el explorador:
			           |""%1""';
			           |es_CO = 'No se ha encontrado carpeta que se requiere abrir en el explorador:
			           |""%1""';
			           |tr = 'Dosya gezgininde açmak istediğiniz klasör bulunamadı: 
			           | ""%1""';
			           |it = 'Impossibile trovare la cartella da aprire in Explorer:
			           |""%1"".';
			           |de = 'Der Ordner, den Sie im Explorer öffnen möchten, wird nicht gefunden:
			           |""%1""'"),
			FileInfo.FullName);
		OpenExplorerNotifyOnError(ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continue the CommonClient.OpenExplorer procedure.
Procedure OpenExplorerAfterCheckIsFIle(IsFile, Context) Export 
	
	FileInfo = Context.FileInfo;
	
	Notification = New NotifyDescription(,,, "OpenExplorerOnProcessError", ThisObject);
	If IsFile Then
		If CommonClientServer.IsWindowsClient() Then
			BeginRunningApplication(Notification, "explorer.exe /select, """ + FileInfo.FullName + """");
		Else // It is Linux or MacOS.
			BeginRunningApplication(Notification, "file:///" + FileInfo.Path);
		EndIf;
	Else // It is a directory.
		BeginRunningApplication(Notification, "file:///" + FileInfo.FullName);
	EndIf;
	
EndProcedure

// Continue the CommonClient.OpenExplorer procedure.
Procedure OpenExplorerOnProcessError(ErrorInformation, StandardProcessing, Context) Export 
	
	StandardProcessing = False;
	OpenExplorerNotifyOnError("", Context);
	
EndProcedure

// Continue the CommonClient.OpenExplorer procedure.
Procedure OpenExplorerNotifyOnError(ErrorDescription, Context)
	
	If Not IsBlankString(ErrorDescription) Then 
		ShowMessageBox(, ErrorDescription);
	EndIf;
	
EndProcedure

#EndRegion

#Region OpenFileInViewer

// Continue the CommonClient.OpenFileInViewer procedure.
Procedure OpenFileInViewerAfterCheckFileSystemExtension(ExtensionAttached, Context) Export
	
	FileInfo = Context.FileInfo;
	
	If ExtensionAttached Then
		Notification = New NotifyDescription(
			"OpenFileInViewerAfterCheckIfExists", ThisObject, Context,
			"OpenFileInViewerOnProcessError", ThisObject);
		FileInfo.BeginCheckingExistence(Notification);
	Else
		ErrorDescription = NStr("ru = 'Расширение для работы с файлами не установлено, открытие файла невозможно.'; en = 'Cannot open the file because the file system extension is not installed.'; pl = 'Rozszerzenie do pracy z plikami nie jest ustanowione, otwarcie pliku jest nie możliwe.';es_ES = 'La extensión del uso de archivos no está instalada, no se puede abrir el archivo.';es_CO = 'La extensión del uso de archivos no está instalada, no se puede abrir el archivo.';tr = 'Dosya işlemi uzantısı yüklü değil, dosya açılamıyor.';it = 'Impossibile aprire il file poiché l''estensione del file di sistema non è installata.';de = 'Dateierweiterung nicht installiert, das Öffnen der Datei ist nicht möglich.'");
		OpenFileInViewerNotifyOnError(ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continue the CommonClient.OpenFileInViewer procedure.
Procedure OpenFileInViewerAfterCheckIfExists(Exists, Context) Export
	
	FileInfo = Context.FileInfo;
	
	If Exists Then 
		Notification = New NotifyDescription(
			"OpenFileInViewerAfterCheckIsFIle", ThisObject, Context,
			"OpenFileInViewerOnProcessError", ThisObject);
		FileInfo.BeginCheckingIsFile(Notification);
	Else 
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не найден файл, который требуется открыть:
			           |%1'; 
			           |en = 'Cannot find the file to open:
			           |%1.'; 
			           |pl = 'Nie jest znaleziony plik, który trzeba otworzyć:
			           |%1';
			           |es_ES = 'No se ha encontrado archivo que se requiere abrir:
			           |%1';
			           |es_CO = 'No se ha encontrado archivo que se requiere abrir:
			           |%1';
			           |tr = 'Açılacak dosya bulunamadı: 
			           |%1';
			           |it = 'Impossibile trovare il file da aprire: 
			           |%1.';
			           |de = 'Es wurde keine zu öffnende Datei gefunden:
			           |%1.'"),
			FileInfo.FullName);
		OpenFileInViewerNotifyOnError(ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continue the CommonClient.OpenFileInViewer procedure.
Procedure OpenFileInViewerAfterCheckIsFIle(IsFile, Context) Export
	
	FileInfo = Context.FileInfo;
	
	If IsFile Then
		
		If IsBlankString(FileInfo.Extension) Then 
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Имя файла не содержит расширения:
				           |%1'; 
				           |en = 'The file name does not include extension:
				           |%1.'; 
				           |pl = 'Nazwa pliku nie zawiera rozszerzenia:
				           |%1';
				           |es_ES = 'El nombre de archivo no contiene extensiones:
				           |%1';
				           |es_CO = 'El nombre de archivo no contiene extensiones:
				           |%1';
				           |tr = 'Dosya adı uzantı içermiyor:
				           |%1.';
				           |it = 'Il nome del file non include l''estensione:
				           |%1.';
				           |de = 'Der Dateiname enthält keine Erweiterung:
				           |%1.'"),
				FileInfo.FullName);
			OpenFileInViewerNotifyOnError(ErrorDescription, Context);
			Return;
		EndIf;
		
		If IsExecutableFileExtension(FileInfo.Extension) Then 
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Исполняемые файлы открывать запрещено:
				           |%1'; 
				           |en = 'Cannot open the executable file because this operation is not allowed:
				           |%1.'; 
				           |pl = 'Otwarcie wykonywanych plików jest zabronione:
				           |%1.';
				           |es_ES = 'Está prohibido abrir archivos ejecutivos:
				           |%1';
				           |es_CO = 'Está prohibido abrir archivos ejecutivos:
				           |%1';
				           |tr = 'Yürütülen dosyalar açılamaz: 
				           |%1';
				           |it = 'Impossibile aprire il file eseguibile poiché questa operazione non è permessa:
				           |%1.';
				           |de = 'Ausführbare Dateien dürfen nicht geöffnet werden:
				           |%1.'"),
				FileInfo.FullName);
			OpenFileInViewerNotifyOnError(ErrorDescription, Context);
			Return;
		EndIf;
		
		Notification          = Context.Notification;
		WaitForCompletion = (Notification <> Undefined);
		
		Notification = New NotifyDescription(
			"OpenFileInViewerAfterStartApplication", ThisObject, Context,
			"OpenFileInViewerOnProcessError", ThisObject);
		BeginRunningApplication(Notification, FileInfo.FullName,, WaitForCompletion);
		
	Else 
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не найден файл, который требуется открыть:
			           |%1'; 
			           |en = 'Cannot find the file to open:
			           |%1.'; 
			           |pl = 'Nie jest znaleziony plik, który trzeba otworzyć:
			           |%1';
			           |es_ES = 'No se ha encontrado archivo que se requiere abrir:
			           |%1';
			           |es_CO = 'No se ha encontrado archivo que se requiere abrir:
			           |%1';
			           |tr = 'Açılacak dosya bulunamadı: 
			           |%1';
			           |it = 'Impossibile trovare il file da aprire: 
			           |%1.';
			           |de = 'Es wurde keine zu öffnende Datei gefunden:
			           |%1.'"),
			FileInfo.FullName);
		OpenFileInViewerNotifyOnError(ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continue the CommonClient.OpenFileInViewer procedure.
Procedure OpenFileInViewerAfterStartApplication(ReturnCode, Context) Export 
	
	Notification = Context.Notification;
	
	If Notification <> Undefined Then 
		ApplicationStarted = (ReturnCode = 0);
		ExecuteNotifyProcessing(Notification, ApplicationStarted);
	EndIf;
	
EndProcedure

// Continue the CommonClient.OpenFileInViewer procedure.
Procedure OpenFileInViewerOnProcessError(ErrorInformation, StandardProcessing, Context) Export 
	
	StandardProcessing = False;
	OpenFileInViewerNotifyOnError("", Context);
	
EndProcedure

// Continue the CommonClient.OpenFileInViewer procedure.
Procedure OpenFileInViewerNotifyOnError(ErrorDescription, Context)
	
	Notification = Context.Notification;
	
	If Notification = Undefined Then
		If Not IsBlankString(ErrorDescription) Then 
			ShowMessageBox(, ErrorDescription);
		EndIf;
	Else 
		ApplicationStarted = False;
		ExecuteNotifyProcessing(Notification, ApplicationStarted);
	EndIf;
	
EndProcedure

// Parameters:
//  Extension - String - the Extension property of the File object.
//
Function IsExecutableFileExtension(Val Extension)
	
	Extension = Upper(Extension);
	
	// Windows
	Return Extension = ".BAT" // Batch File
		Or Extension = ".BIN" // Binary Executable
		Or Extension = ".CMD" // Command Script
		Or Extension = ".COM" // MS-DOS application
		Or Extension = ".CPL" // Control Panel Extension
		Or Extension = ".EXE" // Executable file
		Or Extension = ".GADGET" // Binary Executable
		Or Extension = ".HTA" // HTML Application
		Or Extension = ".INF1" // Setup Information File
		Or Extension = ".INS" // Internet Communication Settings
		Or Extension = ".INX" // InstallShield Compiled Script
		Or Extension = ".ISU" // InstallShield Uninstaller Script
		Or Extension = ".JOB" // Windows Task Scheduler Job File
		Or Extension = ".LNK" // File Shortcut
		Or Extension = ".MSC" // Microsoft Common Console Document
		Or Extension = ".MSI" // Windows Installer Package
		Or Extension = ".MSP" // Windows Installer Patch
		Or Extension = ".MST" // Windows Installer Setup Transform File
		Or Extension = ".OTM" // Microsoft Outlook macro
		Or Extension = ".PAF" // Portable Application Installer File
		Or Extension = ".PIF" // Program Information File
		Or Extension = ".PS1" // Windows PowerShell Cmdlet
		Or Extension = ".REG" // Registry Data File
		Or Extension = ".RGS" // Registry Script
		Or Extension = ".SCT" // Windows Scriptlet
		Or Extension = ".SHB" // Windows Document Shortcut
		Or Extension = ".SHS" // Shell Scrap Object
		Or Extension = ".U3P" // U3 Smart Application
		Or Extension = ".VB"  // VBScript File
		Or Extension = ".VBE" // VBScript Encoded Script
		Or Extension = ".VBS" // VBScript File
		Or Extension = ".VBSCRIPT" // Visual Basic Script
		Or Extension = ".WS"  // Windows Script
		Or Extension = ".WSF" // Windows Script
	// Linux
		Or Extension = ".CSH" // C Shell Script
		Or Extension = ".KSH" // Unix Korn Shell Script
		Or Extension = ".OUT" // Executable file
		Or Extension = ".RUN" // Executable file
		Or Extension = ".SH"  // Shell Script
	// MacOS
		Or Extension = ".ACTION" // Automator Action
		Or Extension = ".APP" // Executable file
		Or Extension = ".COMMAND" // Terminal Command
		Or Extension = ".OSX" // Executable file
		Or Extension = ".WORKFLOW" // Automator Workflow
	// Other
		Or Extension = ".AIR" // Adobe AIR distribution package
		Or Extension = ".COFFIE" // CoffeeScript (JavaScript) script
		Or Extension = ".JAR" // Java archive
		Or Extension = ".JS"  // JScript File
		Or Extension = ".JSE" // JScript Encoded File
		Or Extension = ".PLX" // Perl executable file
		Or Extension = ".PYC" // Python compiled file
		Or Extension = ".PYO"; // Python optimized code
	
EndFunction

#EndRegion

#Region OpenURL

// Continue the CommonClient.OpenURL procedure.
Procedure OpenURLAfterCheckFileSystemExtension(ExtensionAttached, Context) Export
	
	URL = Context.URL;
	
	If ExtensionAttached Then
		
		Notification          = Context.Notification;
		WaitForCompletion = (Notification <> Undefined);
		
		Notification = New NotifyDescription("OpenURLAfterStartApplication", ThisObject, Context,
			"OpenURLOnProcessError", ThisObject);
		BeginRunningApplication(Notification, URL,, WaitForCompletion);
		
	Else
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Расширение для работы с файлами не установлено, переход по ссылке ""%1"" невозможен.'; en = 'Cannot follow the link ""%1"" because the file system extension is not installed.'; pl = 'Rozszerzenie do pracy z plikami nie jest ustanowione, przejście pod linkiem ""%1"" jest niemożliwe.';es_ES = 'La extensión para usar los archivos no está instalada, no se puede pasar por el enlace ""%1"".';es_CO = 'La extensión para usar los archivos no está instalada, no se puede pasar por el enlace ""%1"".';tr = 'Dosya uzantısı yüklü değil, ""%1"" bağlantısına geçilemez.';it = 'Impossibile seguire il file ""%1"" poiché l''estensione del file di sistema non è installata.';de = 'Die Erweiterung für die Arbeit mit Dateien ist nicht installiert, der Link ""%1"" ist nicht möglich.'"),
			URL);
		OpenURLNotifyOnError(ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continue the CommonClient.OpenURL procedure.
Procedure OpenURLAfterStartApplication(ReturnCode, Context) Export 
	
	Notification = Context.Notification;
	
	If Notification <> Undefined Then 
		ApplicationStarted = (ReturnCode = 0 Or ReturnCode = Undefined);
		ExecuteNotifyProcessing(Notification, ApplicationStarted);
	EndIf;
	
EndProcedure

// Continue the CommonClient.OpenURL procedure.
Procedure OpenURLOnProcessError(ErrorInformation, StandardProcessing, Context) Export 
	
	StandardProcessing = False;
	OpenURLNotifyOnError("", Context);
	
EndProcedure

// Continue the CommonClient.OpenURL procedure.
Procedure OpenURLNotifyOnError(ErrorDescription, Context) Export
	
	Notification = Context.Notification;
	
	If Notification = Undefined Then
		If Not IsBlankString(ErrorDescription) Then 
			ShowMessageBox(, ErrorDescription);
		EndIf;
	Else 
		ApplicationStarted = False;
		ExecuteNotifyProcessing(Notification, ApplicationStarted);
	EndIf;
	
EndProcedure

// Checks whether the passed string is a web URL.
// 
// Parameters:
//  String - String - passed URL.
//
Function IsWebURL(Row) Export
	
	Return StrStartsWith(Row, "http://")  // a usual connection.
		Or StrStartsWith(Row, "https://");// a secure connection.
	
EndFunction

// Checks whether the passed string is a reference to the online help.
// 
// Parameters:
//  String - String - passed URL.
//
Function IsHelpRef(Row) Export
	
	Return StrStartsWith(Row, "v8help://");
	
EndFunction

// Checks whether the passed string is a valid reference to the protocol whitelist.
// 
// Parameters:
//  String - String - passed URL.
//
Function IsAllowedRef(Row) Export
	
	Return StrStartsWith(Row, "e1cib/")
		Or StrStartsWith(Row, "http:")
		Or StrStartsWith(Row, "https:")
		Or StrStartsWith(Row, "e1c:")
		Or StrStartsWith(Row, "v8help:")
		Or StrStartsWith(Row, "mailto:")
		Or StrStartsWith(Row, "tel:")
		Or StrStartsWith(Row, "skype:");
	
EndFunction

#EndRegion

#Region StartApplication

// Continue the CommonClient.StartApplication procedure.
Procedure StartApplicationAfterCheckFileSystemExtension(ExtensionAttached, Context) Export
	
	If ExtensionAttached Then
		
		CommandString  = Context.CommandString;
		CurrentDirectory = Context.CurrentDirectory;
		Notification     = Context.Notification;
		
		WaitForCompletion = (Notification <> Undefined);
		
		Notification = New NotifyDescription(
			"StartApplicationAfterStartApplication", ThisObject, Context,
			"StartApplicationOnProcessError", ThisObject);
		BeginRunningApplication(Notification, CommandString, CurrentDirectory, WaitForCompletion);
		
	Else
		ErrorDescription = 
			NStr("ru = 'Расширение для работы с файлами не установлено, запуск программы невозможен.'; en = 'Cannot start the application because the file system extension is not installed.'; pl = 'Rozszerzenie do pracy z plikami nie jest ustanowione, uruchomienie programu jest niemożliwe.';es_ES = 'La extensión del uso de archivos no está instalada, no se puede iniciar el programa.';es_CO = 'La extensión del uso de archivos no está instalada, no se puede iniciar el programa.';tr = 'Dosya işlemi uzantısı yüklü değil, uygulama başlatılamıyor.';it = 'Impossibile avviare l''applicazione poiché l''estensione del file di sistema non è installata.';de = 'Die Dateierweiterung ist nicht installiert, das Programm kann nicht gestartet werden.'");
		StartApplicationNotifyOnError(ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continue the CommonClient.StartApplication procedure.
Procedure StartApplicationAfterStartApplication(ReturnCode, Context) Export 
	
	Notification = Context.Notification;
	
	WaitForCompletion = (Notification <> Undefined);
	
	If WaitForCompletion Then 
		
		If ReturnCode = Undefined Then 
			ErrorDescription = 
				NStr("ru = 'Произошла неизвестная ошибка при запуске программы.'; en = 'An unknown error occurred while starting the application.'; pl = 'Wystąpił nieznany błąd podczas uruchomienia programu.';es_ES = 'Se ha producido un error desconocido al iniciar el programa.';es_CO = 'Se ha producido un error desconocido al iniciar el programa.';tr = 'Uygulama başlatıldığında bilinmeyen bir hata oluştu.';it = 'Un errore sconosciuto si è registrato durante l''avvio dell''applicazione.';de = 'Beim Start des Programms ist ein unbekannter Fehler aufgetreten.'");
			StartApplicationNotifyOnError(ErrorDescription, Context);
		Else 
			Result = ApplicationStartResult();
			Result.ApplicationStarted = True;
			Result.ReturnCode = ReturnCode;
			
			ExecuteNotifyProcessing(Notification, Result);
		EndIf;
	EndIf
	
EndProcedure

// Continue the CommonClient.StartApplication procedure.
Procedure StartApplicationOnProcessError(ErrorInformation, StandardProcessing, Context) Export 
	
	StandardProcessing = False;
	ErrorDescription = BriefErrorDescription(ErrorInformation);
	StartApplicationNotifyOnError(ErrorDescription, Context);
	
EndProcedure

// Continue the CommonClient.StartApplication procedure.
Procedure StartApplicationNotifyOnError(ErrorDescription, Context)
	
	Notification = Context.Notification;
	
	If Notification = Undefined Then
		If Not IsBlankString(ErrorDescription) Then 
			ShowMessageBox(, ErrorDescription);
		EndIf;
	Else 
		Result = ApplicationStartResult();
		Result.ErrorDescription = ErrorDescription;
		ExecuteNotifyProcessing(Notification, Result);
	EndIf;
	
EndProcedure

// Continue the CommonClient.StartApplication procedure.
Function ApplicationStartResult()
	
	Result = New Structure;
	Result.Insert("ApplicationStarted", False);
	Result.Insert("ErrorDescription", "");
	Result.Insert("ReturnCode", -13);
	
	Return Result;
	
EndFunction

#EndRegion

#Region CreateTemporaryDirectory

// Continue the CommonClient.CreateTemporaryDirectory procedure.
Procedure CreateTemporaryDirectoryAfterCheckFileSystemExtension(ExtensionAttached, Context) Export
	
	If ExtensionAttached Then
		
		Notification = New NotifyDescription(
			"CreateTemporaryDirectoryAfterGetTemporaryDirectory", ThisObject, Context,
			"CreateTemporaryDirectoryOnProcessError", ThisObject);
		
		BeginGettingTempFilesDir(Notification);
		
	Else
		ErrorDescription = 
			NStr("ru = 'Расширение для работы с файлами не установлено, создание временного каталога невозможно.'; en = 'Cannot create a temporary directory because the file system extension is not installed.'; pl = 'Rozszerzenie do pracy z plikami nie jest ustanowione, tworzenie tymczasowego katalogu jest niemożliwe.';es_ES = 'La extensión del uso de archivos no está instalada, no se puede crear un catálogo temporal.';es_CO = 'La extensión del uso de archivos no está instalada, no se puede crear un catálogo temporal.';tr = 'Dosya işlemi uzantısı yüklü değil, geçici katalog açılamıyor.';it = 'Impossibile creare una directory temporanea perché l''estensione del file di sistema non è installata.';de = 'Erweiterung für die Arbeit mit Dateien ist nicht installiert, die Erstellung eines temporären Verzeichnisses ist nicht möglich.'");
		CreateTemporaryDirectoryNotifyOnError(ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continue the CommonClient.CreateTemporaryDirectory procedure.
Procedure CreateTemporaryDirectoryAfterGetTemporaryDirectory(TemporaryFileDirectoryName, Context) Export 
	
	Notification = Context.Notification;
	Extension = Context.Extension;
	
	DirectoryName = "v8_" + String(New UUID);
	
	If Not IsBlankString(Extension) Then 
		DirectoryName = DirectoryName + "." + Extension;
	EndIf;
	
	BeginCreatingDirectory(Notification, TemporaryFileDirectoryName + DirectoryName);
	
EndProcedure

// Continue the CommonClient.CreateTemporaryDirectory procedure.
Procedure CreateTemporaryDirectoryOnProcessError(ErrorInformation, StandardProcessing, Context) Export 
	
	StandardProcessing = False;
	ErrorDescription = BriefErrorDescription(ErrorInformation);
	CreateTemporaryDirectoryNotifyOnError(ErrorDescription, Context);
	
EndProcedure

// Continue the CommonClient.CreateTemporaryDirectory procedure.
Procedure CreateTemporaryDirectoryNotifyOnError(ErrorDescription, Context)
	
	ShowMessageBox(, ErrorDescription);
	DirectoryName = "";
	ExecuteNotifyProcessing(Context.Notification, DirectoryName);
	
EndProcedure

#EndRegion

#Region OtherProceduresAndFunctions

Procedure ShowFileSystemExtensionInstallationOnInstallExtension(Attached, AdditionalParameters) Export
	
	// If the extension is already installed, there is no need to ask about it
	If Attached Then
		ExecuteNotifyProcessing(AdditionalParameters.NotifyDescriptionCompletion, "AttachmentNotRequired");
		Return;
	EndIf;
	
	// The extension is not available for the MacOS web client.
	SystemInfo = New SystemInfo;
	IsMacClient = (SystemInfo.PlatformType = PlatformType.MacOS_x86
		Or SystemInfo.PlatformType = PlatformType.MacOS_x86_64);
	If IsMacClient Then
		ExecuteNotifyProcessing(AdditionalParameters.NotifyDescriptionCompletion);
		Return;
	EndIf;
	
	ParameterName = "StandardSubsystems.SuggestFileSystemExtensionInstallation";
	FirstCallDuringSession = ApplicationParameters[ParameterName] = Undefined;
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, CommonClient.SuggestFileSystemExtensionInstallation());
	EndIf;
	SuggestFileSystemExtensionInstallation	= ApplicationParameters[ParameterName] Or FirstCallDuringSession;
	
	If AdditionalParameters.CanContinueWithoutInstalling AND Not SuggestFileSystemExtensionInstallation Then
		ExecuteNotifyProcessing(AdditionalParameters.NotifyDescriptionCompletion);
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("SuggestionText", AdditionalParameters.SuggestionText);
	FormParameters.Insert("CanContinueWithoutInstalling", AdditionalParameters.CanContinueWithoutInstalling);
	OpenForm("CommonForm.FileSystemExtensionInstallationQuestion", FormParameters,,,,,AdditionalParameters.NotifyDescriptionCompletion);
	
EndProcedure

Procedure ShowFileSystemExtensionInstallationQuestionCompletion(Action, ClosingNotification) Export
	
	ExtensionAttached = (Action = "ExtensionAttached" Or Action = "AttachmentNotRequired");
#If WebClient Then
	If Action = "DoNotPrompt"
		Or Action = "ExtensionAttached" Then
		SystemInfo = New SystemInfo();
		ClientID = SystemInfo.ClientID;
		ApplicationParameters["StandardSubsystems.SuggestFileSystemExtensionInstallation"] = False;
		CommonServerCall.CommonSettingsStorageSave(
			"ApplicationSettings/SuggestFileSystemExtensionInstallation", ClientID, False);
	EndIf;
#EndIf
	
	ExecuteNotifyProcessing(ClosingNotification, ExtensionAttached);
	
EndProcedure

Procedure CheckFileSystemExtensionAttachedCompletion(ExtensionAttached, AdditionalParameters) Export
	
	If ExtensionAttached Then
		ExecuteNotifyProcessing(AdditionalParameters.OnCloseNotifyDescription);
		Return;
	EndIf;
	
	MessageText = AdditionalParameters.WarningText;
	If IsBlankString(MessageText) Then
		MessageText = NStr("ru = 'Действие недоступно, так как не установлено расширение для веб-клиента 1С:Предприятие.'; en = 'Cannot perform the operation because 1C:Enterprise web client extension is not installed.'; pl = 'Ta czynność jest niedostępna ponieważ rozszerzenie dla klienta sieci Web 1C:Enterprise nie jest zainstalowane.';es_ES = 'La acción no está disponible porque una extensión para el cliente web de la 1C:Empresa no está instalada.';es_CO = 'La acción no está disponible porque una extensión para el cliente web de la 1C:Empresa no está instalada.';tr = '1C:Enterprise web istemcisi uzantısı yüklü olmadığı için işlem gerçekleştirilemiyor.';it = 'Impossibile eseguire l''operazione poiché l''estensione del web client 1C:Enterprise non è installata.';de = 'Die Operation kann nicht durchgeführt werden, denn die Erweiterung von 1C: Enterprise-Webclient ist nicht installiert.'")
	EndIf;
	ShowMessageBox(, MessageText);
	
EndProcedure

Procedure CommentInputCompletion(Val EnteredText, Val AdditionalParameters) Export
	
	If EnteredText = Undefined Then
		Return;
	EndIf;	
	
	FormAttribute = AdditionalParameters.OwnerForm;
	
	PathToFormAttribute = StrSplit(AdditionalParameters.AttributeName, ".");
	// If the type of the attribute is "Object.Comment" and so on
	If PathToFormAttribute.Count() > 1 Then
		For Index = 0 To PathToFormAttribute.Count() - 2 Do 
			FormAttribute = FormAttribute[PathToFormAttribute[Index]];
		EndDo;
	EndIf;	
	
	FormAttribute[PathToFormAttribute[PathToFormAttribute.Count() - 1]] = EnteredText;
	AdditionalParameters.OwnerForm.Modified = True;
	
EndProcedure

Procedure RegisterCOMConnectorCompletion(Response, Parameters) Export
	
	If Response = DialogReturnCode.Yes Then
		ApplicationParameters.Insert("StandardSubsystems.SkipExitConfirmation", True);
		Exit(True, True);
	EndIf;

EndProcedure

Procedure ConfirmFormClosing() Export
	
	ParameterName = "StandardSubsystems.FormClosingConfirmationParameters";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	
	Parameters = ApplicationParameters["StandardSubsystems.FormClosingConfirmationParameters"];
	If Parameters = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("ConfirmFormClosingCompletion", ThisObject, Parameters);
	If IsBlankString(Parameters.WarningText) Then
		QuestionText = NStr("ru = 'Данные были изменены. Сохранить изменения?'; en = 'The data was changed. Do you want to save the changes?'; pl = 'Dane zostały zmienione. Czy chcesz zapisać zmiany?';es_ES = 'Datos se han cambiado. ¿Quiere guardar los cambios?';es_CO = 'Datos se han cambiado. ¿Quiere guardar los cambios?';tr = 'Veriler değiştirildi. Değişiklikleri kaydetmek istiyor musunuz?';it = 'I dati sono stati modificati. Volete salvare le modifiche?';de = 'Daten wurden geändert. Wollen Sie die Änderungen speichern?'");
	Else
		QuestionText = Parameters.WarningText;
	EndIf;
	
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNoCancel, ,
		DialogReturnCode.No);
	
EndProcedure

Procedure ConfirmFormClosingCompletion(Response, Parameters) Export
	
	ApplicationParameters["StandardSubsystems.FormClosingConfirmationParameters"] = Undefined;
	
	If Response = DialogReturnCode.Yes Then
		ExecuteNotifyProcessing(Parameters.SaveAndCloseNotification);
		
	ElsIf Response = DialogReturnCode.No Then
		Form = Parameters.SaveAndCloseNotification.Module;
		Form.Modified = False;
		Form.Close();
	Else
		Form = Parameters.SaveAndCloseNotification.Module;
		Form.Modified = True;
	EndIf;
	
EndProcedure

Procedure ConfirmArbitraryFormClosing() Export
	
	ParameterName = "StandardSubsystems.FormClosingConfirmationParameters";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	
	Parameters = ApplicationParameters["StandardSubsystems.FormClosingConfirmationParameters"];
	If Parameters = Undefined Then
		Return;
	EndIf;
	ApplicationParameters["StandardSubsystems.FormClosingConfirmationParameters"] = Undefined;
	QuestionMode = QuestionDialogMode.YesNo;
	
	Notification = New NotifyDescription("ConfirmArbitraryFormClosingCompletion", ThisObject, Parameters);
	
	ShowQueryBox(Notification, Parameters.WarningText, QuestionMode);
	
EndProcedure

Procedure ConfirmArbitraryFormClosingCompletion(Response, Parameters) Export
	
	Form = Parameters.Form;
	If Response = DialogReturnCode.Yes
		Or Response = DialogReturnCode.OK Then
		Form[Parameters.CloseFormWithoutConfirmationAttributeName] = True;
		If Parameters.CloseNotifyDescription <> Undefined Then
			ExecuteNotifyProcessing(Parameters.CloseNotifyDescription);
		EndIf;
		Form.Close();
	Else
		Form[Parameters.CloseFormWithoutConfirmationAttributeName] = False;
	EndIf;
	
EndProcedure

Function MetadataObjectName(Type) Export
	
	ParameterName = "StandardSubsystems.MetadataObjectNames";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New Map);
	EndIf;
	MetadataObjectNames = ApplicationParameters[ParameterName];
	
	Result = MetadataObjectNames[Type];
	If Result = Undefined Then
		Result = StandardSubsystemsServerCall.MetadataObjectName(Type);
		MetadataObjectNames.Insert(Type, Result);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion