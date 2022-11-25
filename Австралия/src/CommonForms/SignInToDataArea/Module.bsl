#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StandardSubsystemsServer.SetBlankFormOnBlankHomePage();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	RefreshInterface = False;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SignInToDataArea(Command)
	
	If LoggedOnToDataArea() Then
		SignOutOfDataAreaAtServer();
		RefreshInterface = True;
		StandardSubsystemsClient.SetAdvancedApplicationCaption(True);
		
		AttachIdleHandler("SignInToDataAreaAfterSignOut", 0.1, True);
		SetButtonsAvailability(False);
	Else
		SignInToDataAreaAfterSignOut();
	EndIf;
	
EndProcedure

&AtClient
Procedure SignOutOfDataArea(Command)
	
	If LoggedOnToDataArea() Then
		// Closing separated desktop forms.
		RefreshInterface();
		AttachIdleHandler("ContinueSignOutOfDataAreaAfterHideDesktopForms", 0.1, True);
		SetButtonsAvailability(False);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure RefreshInterfaceIfNecessary()
	
	If RefreshInterface Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

&AtClient
Procedure SignInToDataAreaAfterSignOut()
	
	SetButtonsAvailability(True);
	
	If NOT IsDataAreaFilled(DataArea) Then
		NotifyDescription = New NotifyDescription("SignInToDataAreaAfterSignOut2", ThisObject);
		ShowQueryBox(NotifyDescription, NStr("ru = 'Выбранная область данных не используется, продолжить вход?'; en = 'The selected data area is not used. Do you want to sign in?'; pl = 'Wybrany obszar danych nie jest używany, kontynuować logowanie?';es_ES = 'Área de datos seleccionada no se utiliza, ¿continuar el inicio de sesión?';es_CO = 'Área de datos seleccionada no se utiliza, ¿continuar el inicio de sesión?';tr = 'Seçilen veri alanı kullanılmıyor, giriş devam edilsin mi?';it = 'L''area dati selezionata non è in uso, accedere lo stesso?';de = 'Der ausgewählte Datenbereich wird nicht verwendet, Anmeldung fortsetzen?'"),
			QuestionDialogMode.YesNo, , DialogReturnCode.No);
		Return;
	EndIf;
	
	SignInToDataAreaAfterSignOut2();
	
EndProcedure

&AtClient
Procedure SignInToDataAreaAfterSignOut2(Response = Undefined, AdditionalParameters = Undefined) Export
	
	If Response = DialogReturnCode.No Then
		RefreshInterfaceIfNecessary();
		Return;
	EndIf;
	
	SignInToDataAreaAtServer(DataArea);
	
	RefreshInterface = True;
	
	CompletionProcessing = New NotifyDescription(
		"ContinueSignInToDataAreaAfterBeforeStartActions", ThisObject);
	
	StandardSubsystemsClient.BeforeStart(CompletionProcessing);
	
EndProcedure

&AtClient
Procedure ContinueSignInToDataAreaAfterBeforeStartActions(Result, Context) Export
	
	If Result.Cancel Then
		SignOutOfDataAreaAtServer();
		RefreshInterface = True;
		StandardSubsystemsClient.SetAdvancedApplicationCaption(True);
		RefreshInterfaceIfNecessary();
		Activate();
		SetButtonsAvailability(False);
		AttachIdleHandler("EnableButtonsAvailability", 2, True);
	Else
		CompletionProcessing = New NotifyDescription(
			"ContinueSignInToDataAreaAfterOnStartActions", ThisObject);
		
		StandardSubsystemsClient.OnStart(CompletionProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure ContinueSignInToDataAreaAfterOnStartActions(Result, Context) Export
	
	If Result.Cancel Then
		SignOutOfDataAreaAtServer();
		RefreshInterface = True;
		StandardSubsystemsClient.SetAdvancedApplicationCaption(True);
	EndIf;
	
	RefreshInterfaceIfNecessary();
	Activate();
	
	SetButtonsAvailability(False);
	AttachIdleHandler("EnableButtonsAvailability", 2, True);
	Notify("LoggedOnToDataArea");
	
EndProcedure

&AtClient
Procedure ContinueSignOutOfDataAreaAfterHideDesktopForms()
	
	SetButtonsAvailability(True);
	
	SignOutOfDataAreaAtServer();
	
	// Displaying shared desktop forms.
	RefreshInterface();
	
	StandardSubsystemsClient.SetAdvancedApplicationCaption(True);
	
	Activate();
	
	SetButtonsAvailability(False);
	AttachIdleHandler("EnableButtonsAvailability", 2, True);
	Notify("LoggedOffFromDataArea");
	
EndProcedure

&AtServerNoContext
Function IsDataAreaFilled(Val DataArea)
	
	SetPrivilegedMode(True);
	
	Lock = New DataLock;
	LockItem = Lock.Add("InformationRegister.DataAreas");
	LockItem.SetValue("DataAreaAuxiliaryData", DataArea);
	LockItem.Mode = DataLockMode.Shared;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreas.Status AS Status
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|WHERE
	|	DataAreas.DataAreaAuxiliaryData = &DataArea";
	Query.SetParameter("DataArea", DataArea);
	
	BeginTransaction();
	Try
		Lock.Lock();
		Result = Query.Execute();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Result.IsEmpty() Then
		Return False;
	Else
		Selection = Result.Select();
		Selection.Next();
		Return Selection.Status = Enums.DataAreaStatuses.Used
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure SignInToDataAreaAtServer(Val DataArea)
	
	SetPrivilegedMode(True);
	
	SaaS.SetSessionSeparation(True, DataArea);
	
	BeginTransaction();
	
	Try
		
		AreaKey = SaaS.CreateAuxiliaryDataInformationRegisterRecordKey(
			InformationRegisters.DataAreas,
			New Structure(SaaS.AuxiliaryDataSeparator(), DataArea));
		LockDataForEdit(AreaKey);
		
		Lock = New DataLock;
		Item = Lock.Add("InformationRegister.DataAreas");
		Item.SetValue("DataAreaAuxiliaryData", DataArea);
		Item.Mode = DataLockMode.Shared;
		Lock.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.DataAreaAuxiliaryData = DataArea;
		RecordManager.Read();
		If Not RecordManager.Selected() Then
			RecordManager.DataAreaAuxiliaryData = DataArea;
			RecordManager.Status = Enums.DataAreaStatuses.Used;
			RecordManager.Write();
		EndIf;
		UnlockDataForEdit(AreaKey);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtServer
Procedure SignOutOfDataAreaAtServer()
	
	SetPrivilegedMode(True);
	
	// Restoring separated desktop forms.
	StandardSubsystemsServerCall.HideDesktopOnStart(False);
	
	StandardSubsystemsServer.SetBlankFormOnBlankHomePage();
	
	SaaS.SetSessionSeparation(False);
	
EndProcedure

&AtServerNoContext
Function LoggedOnToDataArea()
	
	SetPrivilegedMode(True);
	LoggedOn = SaaS.SessionSeparatorUsage();
	
	// Preparing to close the separated desktop forms.
	If LoggedOn Then
		StandardSubsystemsServerCall.HideDesktopOnStart(True);
	EndIf;
	
	Return LoggedOn;
	
EndFunction

&AtClient
Procedure EnableButtonsAvailability()
	
	SetButtonsAvailability(True);
	
EndProcedure

&AtClient
Procedure SetButtonsAvailability(Availability)
	
	Items.SeparatorValue.Enabled = Availability;
	Items.SignInToDataAreaGroup.Enabled = Availability;
	
EndProcedure

#EndRegion
