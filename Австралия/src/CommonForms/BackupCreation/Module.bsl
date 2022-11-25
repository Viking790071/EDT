#Region Variables

&AtClient
Var IdleHandlerParameters;

&AtClient
Var TimeConsumingOperationForm;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not SaaS.SessionSeparatorUsage() Then 
		Raise(NStr("ru = 'Не установлено значение разделителя'; en = 'The separator value is not specified.'; pl = 'Nie ustawiono wartości separatora';es_ES = 'Valor del separador no está establecido';es_CO = 'Valor del separador no está establecido';tr = 'Ayırıcı değeri ayarlanmadı';it = 'Il valore di separazione non è specificato.';de = 'Trennzeichenwert ist nicht festgelegt'"));
	EndIf;
	
	SwitchPage(ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateAreaCopy(Command)
	
	Result = CreateAreaCopyAtServer();
	
	If Result.Status = "Completed" Then
		ProcessJobExecutionResult();
	ElsIf Result.Status = "Running" Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
		TimeConsumingOperationForm = TimeConsumingOperationsClient.OpenTimeConsumingOperationForm(ThisObject, JobID);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If TimeConsumingOperationForm.IsOpen() 
			AND TimeConsumingOperationForm.JobID = JobID Then
			
			If JobCompleted(JobID) Then 
				TimeConsumingOperationsClient.CloseTimeConsumingOperationForm(TimeConsumingOperationForm);
				ProcessJobExecutionResult();
			Else
				TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
				AttachIdleHandler(
					"Attachable_CheckJobExecution", 
					IdleHandlerParameters.CurrentInterval, 
					True);
			EndIf;
		EndIf;
	Except
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		TimeConsumingOperationsClient.CloseTimeConsumingOperationForm(TimeConsumingOperationForm);
		WriteExceptionsAtServer(ErrorPresentation);
		Raise;
	EndTry;
	
EndProcedure

&AtClient
Procedure ProcessJobExecutionResult()
	
	DisableExclusiveMode();
	
	If Not IsBlankString(StorageAddress) Then
		DeleteFromTempStorage(StorageAddress);
		StorageAddress = "";
		// Navigating to the result page.
		SwitchPage(ThisObject, "PageAfterExportSuccess");
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SwitchPage(Form, Val PageName = "PageBeforeExport")
	
	Form.Items.PagesGroup.CurrentPage = Form.Items[PageName];
	
	If PageName = "PageBeforeExport" Then
		Form.Items.FormCreateAreaCopy.Enabled = True;
	Else
		Form.Items.FormCreateAreaCopy.Enabled = False;
	EndIf;

EndProcedure

&AtServer
Procedure WriteExceptionsAtServer(Val ErrorPresentation)
	
	DisableExclusiveMode();
	
	Event = DataAreaBackup.BackgroundBackupDescription();
	WriteLogEvent(Event, EventLogLevel.Error, , , ErrorPresentation);
	
EndProcedure

&AtServer
Function CreateAreaCopyAtServer()
	
	DataArea = SaaS.SessionSeparatorValue();
	SetExclusiveMode(True);
	
	JobParameters = DataAreaBackup.CreateEmptyExportParameters();
	JobParameters.DataArea = DataArea;
	JobParameters.BackupID = New UUID;
	JobParameters.Forcibly = True;
	JobParameters.OnDemand = True;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(ThisObject.UUID);
	ExecutionParameters.BackgroundJobDescription = DataAreaBackup.BackgroundBackupDescription();
	ExecutionParameters.RunInBackground = True;
	
	Try
		
		
		
		Result = TimeConsumingOperations.ExecuteInBackground(
			DataAreaBackup.BackgroundBackupMethodName(),
			JobParameters,
			ExecutionParameters);
		
	Except
		ErrorPresentation = DetailErrorDescription(ErrorInfo());
		WriteExceptionsAtServer(ErrorPresentation);
		Raise;
	EndTry;
	
	StorageAddress = Result.ResultAddress;
	JobID = Result.JobID;
	Return Result;
	
EndFunction

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return TimeConsumingOperations.JobCompleted(JobID);
	
EndFunction

&AtServerNoContext
Procedure DisableExclusiveMode()
	
	SetExclusiveMode(False);
	
EndProcedure

#EndRegion
