#Region Variables

&AtClient
Var CurrentWriteParameters;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		Object.FillOrder = FindMaxOrder() + 1;
	Else
		Items.FullPathLinux.WarningOnEditRepresentation
			= WarningOnEditRepresentation.Show;
		
		Items.FullPathWindows.WarningOnEditRepresentation
			= WarningOnEditRepresentation.Show;
		
		CurrentSizeInBytes = FilesOperationsInternalServerCall.CalculateFileSizeInVolume(
			Object.Ref);
			
		ActualSize = CurrentSizeInBytes / (1024 * 1024);
		If ActualSize = 0 AND CurrentSizeInBytes <> 0 Then
			ActualSize = 1;
		EndIf;
	EndIf;
	
	SystemInfo = New SystemInfo;
	ServerPlatformType = SystemInfo.PlatformType;
	If ServerPlatformType = PlatformType.Windows_x86
	 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
		
		Items.FullPathWindows.AutoMarkIncomplete = True;
	Else
		Items.FullPathLinux.AutoMarkIncomplete = True;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommonClientServer.SetFormItemProperty(Items, "FormWriteAndClose", "Picture", PictureLib.WriteAndClose);
		CommonClientServer.SetFormItemProperty(Items, "FormWriteAndClose", "Representation", ButtonRepresentation.Picture);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseNotification", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not WriteParameters.Property("ExternalResourcesAllowed") Then
		Cancel = True;
		CurrentWriteParameters = WriteParameters;
		AttachIdleHandler("AllowExternalResourceBeginning", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If ValueIsFilled(NewRef) AND CurrentObject.IsNew() Then
		CurrentObject.SetNewObjectRef(NewRef);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If WriteParameters.Property("WriteAndClose") Then
		Close();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	CurrentObject = FormAttributeToValue("Object");
	
	If FillCheckAlreadyExecuted Then
		FillCheckAlreadyExecuted = False;
		CurrentObject.AdditionalProperties.Insert("SkipBasicFillingCheck");
	Else
		CurrentObject.AdditionalProperties.Insert("SkipDirectoryAccessCheck");
	EndIf;
	
	CheckedAttributes.Clear();
	
	If Not CurrentObject.CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FullPathWindowsOnChange(Item)
	
	// Deleting extra spaces and adding a slash at the end if it is missing.
	If Not IsBlankString(Object.FullPathWindows) Then
		
		If StrStartsWith(Object.FullPathWindows, " ") Or StrEndsWith(Object.FullPathWindows, " ") Then
			Object.FullPathWindows = TrimAll(Object.FullPathWindows);
		EndIf;
		
		If Not StrEndsWith(Object.FullPathWindows, "\") Then
			Object.FullPathWindows = Object.FullPathWindows + "\";
		EndIf;
		
		If StrEndsWith(Object.FullPathWindows, "\\") Then
			Object.FullPathWindows = Left(Object.FullPathWindows, StrLen(Object.FullPathWindows) - 1);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FullPathLinuxOnChange(Item)
	
	// Deleting extra spaces and adding a slash at the end if it is missing.
	If Not IsBlankString(Object.FullPathLinux) Then
		
		If StrStartsWith(Object.FullPathLinux, " ") Or StrEndsWith(Object.FullPathLinux, " ") Then
			Object.FullPathLinux = TrimAll(Object.FullPathLinux);
		EndIf;
		
		If Not StrEndsWith(Object.FullPathLinux, "/") Then
			Object.FullPathLinux = Object.FullPathLinux + "/";
		EndIf;
		
		If StrEndsWith(Object.FullPathLinux, "//") Then
			Object.FullPathLinux = Left(Object.FullPathLinux, StrLen(Object.FullPathLinux) - 1);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	Write(New Structure("WriteAndClose"));
	
EndProcedure

&AtClient
Procedure CheckVolumeIntegrity(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	If NOT ValueIsFilled(Object.Ref) Then
			QuestionText = NStr("ru = 'Для выполнения проверки целостности требуется записать сведения о томе. Записать?'; 
					|en = 'To perform integrity check, save the volume information. Do you want to save the volume information?'; 
					|pl = 'Aby wykonać sprawdzenie integralności, zapisz informację o woluminie. Czy chcesz zapisać informację o woluminie?';
					|es_ES = 'Para comprobar la integridad, guarde la información del tomo. ¿Quiere guardar la información del tomo?';
					|es_CO = 'Para comprobar la integridad, guarde la información del tomo. ¿Quiere guardar la información del tomo?';
					|tr = 'Bütünlük kontrolünü gerçekleştirmek için birim bilgisini kaydedin. Birim bilgisini kaydetmek istiyor musunuz?';
					|it = 'Per effettuare la verifica di integrità, salvare le informazioni di volume. Salvare le informazioni di volume?';
					|de = 'Um Integrität zu prüfen, speichern Sie die Informationsmenge. Möchten Sie die Informationsmenge speichern?'");
			Notification = New NotifyDescription("WriteFormRequiredToCheckVolumeIntegrity", ThisObject);
			ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo);
	Else
		RunVolumeIntegrityCheck();
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteUnnecessaryFiles(Command)
	OpeningParameters = New Structure("FileStorageVolume", Object.Ref);
	OpenForm("Catalog.FileStorageVolumes.Form.DeleteUnnecessaryFilesFromVolume", OpeningParameters, ThisObject);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure WriteFormRequiredToCheckVolumeIntegrity(Write, AdditionalParameters) Export
	
	If Write = DialogReturnCode.Yes Then
		WriteAtServer();
		RunVolumeIntegrityCheck();
	EndIf;
	
EndProcedure

&AtClient
Procedure RunVolumeIntegrityCheck()
	
	ReportParameters = New Structure();
	ReportParameters.Insert("GenerateOnOpen", True);
	ReportParameters.Insert("Filter", New Structure("Volume", Object.Ref));
	
	OpenForm("Report.VolumeIntegrityCheck.ObjectForm", ReportParameters);

EndProcedure

&AtClient
Procedure WriteAndCloseNotification(Result, Context) Export
	
	Write(New Structure("WriteAndClose"));
	
EndProcedure

// Finds maximum order among the volumes.
&AtServer
Function FindMaxOrder()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MAX(Volumes.FillOrder) AS MaxNumber
	|FROM
	|	Catalog.FileStorageVolumes AS Volumes";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		If Selection.MaxNumber = Null Then
			Return 0;
		Else
			Return Number(Selection.MaxNumber);
		EndIf;
	EndIf;
	
	Return 0;
	
EndFunction

&AtClient
Procedure AllowExternalResourceBeginning()
	
	ClosingNotification = New NotifyDescription(
			"AllowExternalResourceCompletion", ThisObject, CurrentWriteParameters);
	
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ExternalResourceQueries = New Array;
		If Not CheckFillingAtServer(ExternalResourceQueries) Then
			Return;
		EndIf;
		
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(ExternalResourceQueries, ThisObject, ClosingNotification);
		
	Else
		
		ExecuteNotifyProcessing(ClosingNotification, DialogReturnCode.OK);
		
	EndIf;
	
EndProcedure

&AtServer
Function CheckFillingAtServer(ExternalResourceQueries)
	
	If Not CheckFilling() Then
		Return False;
	EndIf;
	
	FillCheckAlreadyExecuted = True;
	
	If ValueIsFilled(Object.Ref) Then
		ObjectRef = Object.Ref;
	Else
		If Not ValueIsFilled(NewRef) Then
			NewRef = Catalogs.FileStorageVolumes.GetRef();
		EndIf;
		ObjectRef = NewRef;
	EndIf;
	
	ExternalResourceQueries.Add(
		Catalogs.FileStorageVolumes.RequestToUseExternalResourcesForVolume(
			ObjectRef, Object.FullPathWindows, Object.FullPathLinux));
	
	Return True;
	
EndFunction

&AtClient
Procedure AllowExternalResourceCompletion(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.OK Then
		WriteParameters.Insert("ExternalResourcesAllowed");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtServer
Procedure WriteAtServer()
	Write();
EndProcedure

#EndRegion
