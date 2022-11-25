
#Region Internal

Procedure SetNewStatus(Form, ProcedureParameters, ProcessStatusChangeCallback = Undefined) Export
	
	BackgroundJob = AccountingApprovalServerCall.StartAccountingEntriesChangingInBackgroundJob(ProcedureParameters);
	
	WaitSettings = TimeConsumingOperationsClient.IdleParameters(Form);
	WaitSettings.OutputIdleWindow = False;
	
	ProcedureParameters.Insert("Form", Form);
	ProcedureParameters.Insert("ProcessStatusChangeCallback", ProcessStatusChangeCallback);
	Handler = New NotifyDescription("AfterStatusChanging", AccountingApprovalClient, ProcedureParameters);
	TimeConsumingOperationsClient.WaitForCompletion(BackgroundJob, Handler, WaitSettings);
	
EndProcedure

#EndRegion

#Region Private

Procedure AfterStatusChanging(BackgroundJob, AdditionalParameters) Export

	If BackgroundJob <> Undefined
		And BackgroundJob.Status = "Completed" Then
		
		ShowUserNotification(
			NStr("en = 'Changed'; ru = 'Изменено';pl = 'Zmieniono';es_ES = 'Cambiado';es_CO = 'Cambiado';tr = 'Değiştirilmiş';it = 'Modificato';de = 'Geändert'"),
			,
			NStr("en = 'Accounting entries status has been changed.'; ru = 'Состояние бухгалтерских проводок изменено.';pl = 'Status wpisów księgowych został zmieniony.';es_ES = 'Se ha cambiado el estado de las entradas contables.';es_CO = 'Se ha cambiado el estado de las entradas contables.';tr = 'Muhasebe girişleri durumu değiştirildi.';it = 'Lo stato degli inserimenti contabili è stato modificato.';de = 'Der Buchungsstatus wurde geändert.'")
			,
			PictureLib.Information32);
			
			Form = AdditionalParameters.Form;
			
		If AdditionalParameters.Property("Document") Then
			
			If AdditionalParameters.Property("ProcessStatusChangeCallback") Then
				
				ExecuteNotifyProcessing(
					AdditionalParameters.ProcessStatusChangeCallback, 
					AdditionalParameters.Status);
				
			Else
				Form.AfterStatusChangingAtServer(BackgroundJob.ResultAddress);
			EndIf;
			
			If TypeOf(AdditionalParameters.Document) = Type("DynamicListRowKey") Then
				NotifyChanged(AdditionalParameters.Document.Ref);
				Form.Items.DocumentList.Refresh();
			Else
				NotifyChanged(AdditionalParameters.Document);
				Form.Items.RecordSet.Refresh();
			EndIf;
			
		ElsIf Form.Items.Find("DocumentList") <> Undefined Then
			Form.Items.DocumentList.Refresh();
				Form.RefreshDataAtServer(Form.DocumentList.SettingsComposer, AdditionalParameters.DocumentsArray);
				Form.DocumentListOnActivateRow("");
		EndIf;
		
	Else
		
		If BackgroundJob <> Undefined Then
			ErrorText = NStr("en = 'Cannot change accounting entries status.
				|For more details, see the event log.'; 
				|ru = 'Не удалось изменить состояние бухгалтерских проводок.
				|См. подробности в журнале регистрации.';
				|pl = 'Nie można zmienić statusu wpisów księgowych.
				|Szczegóły w dzienniku rejestracji.';
				|es_ES = 'No se ha podido cambiar el estado de las entradas contables.
				|Para más detalles vea el registro de eventos.';
				|es_CO = 'No se ha podido cambiar el estado de las entradas contables.
				|Para más detalles vea el registro de eventos.';
				|tr = 'Muhasebe girişleri durumu değiştirilemedi.
				|Ayrıntılar için kayıt günlüğüne bakın.';
				|it = 'Impossibile modificare lo stato degli inserimenti contabili. 
				|Per saperne di più, consultare il registro degli eventi.';
				|de = 'Kann den Status von Buchungen nicht ändern.
				|Für weitere Informationen siehe Ereignisprotokoll.'");
			CommonClientServer.MessageToUser(ErrorText);
		EndIf;
		
	EndIf;

EndProcedure

Procedure AdjustManuallyOnChangeEnd(QuestionResult, AdditionalParameters) Export

	Form = AdditionalParameters.Form;
	
	If QuestionResult = DialogReturnCode.Yes Then
		
		Result = Form.RestoreOriginalEntries();
		
		If Result Then
			
			Form.Status = PredefinedValue("Enum.AccountingEntriesStatus.NotApproved");
			Form.Comment = Undefined;
			
			ProcedureParameters = New Structure("Status, AdjustedManually, Comment, UUID");
			FillPropertyValues(ProcedureParameters, Form);
			If AdditionalParameters.Property("DocumentsArray") Then
				ProcedureParameters.Insert("DocumentsArray", AdditionalParameters.DocumentsArray);
			Else
				ProcedureParameters.Insert("Document", AdditionalParameters.Document);
			EndIf;
			
			SetNewStatus(Form, ProcedureParameters);
			Form.Modified = False;
			
			If AdditionalParameters.Property("DocumentsArray") Then
			Else
				NotifyChanged(AdditionalParameters.Document);
			EndIf;
			
			If AdditionalParameters.Property("AdjustManuallyOnChangeEndCallback") Then
				ExecuteNotifyProcessing(AdditionalParameters.AdjustManuallyOnChangeEndCallback, False);
			EndIf;
			
		Else
			Form.AdjustedManually = True;
			Form.FormManagement();
		EndIf;
		
	Else
		Form.AdjustedManually = True;
		Form.FormManagement();
	EndIf;

EndProcedure

Procedure BeforeWriteEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		
		Form = AdditionalParameters.Form;
		Form.ApprovalQuestionWasShown = True;
		Form.Write(AdditionalParameters.WriteParameters);
		
	EndIf;

EndProcedure

#EndRegion
