
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InitialExecutionFlag = Object.Executed;
	ReadOnly = Object.Executed;
	Items.NotApproved.Enabled = Not Object.Executed;
	
	If Not Object.Executed Then
		Object.CompletionDate = CurrentSessionDate();	
	EndIf;

EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Approved(Command)

	ClearMessages();
	
	If Write() Then
		
		WriteApprovalDetails(True);
		Notify("Write_PurchaseApproval");
		NotifyChanged(Object.Ref);
		
		ShowUserNotification(
			NStr("en = 'Approved'; ru = 'Утвержден';pl = 'Zatwierdzony';es_ES = 'Aprobado';es_CO = 'Aprobado';tr = 'Onaylandı';it = 'Approvato';de = 'Genehmigt'"),
			GetURL(Object.Ref),
			String(Object.Ref),
			PictureLib.Information32);
		
		Close();
		
	EndIf;

EndProcedure

&AtClient
Procedure NotApproved(Command)

	ClearMessages();
	If Not ValueIsFilled(Object.ExecutionResult) Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'Please specify a reason for rejection.'; ru = 'Укажите причину отказа.';pl = 'Wybierz przyczynę odrzucenia.';es_ES = 'Por favor, especifique el motivo del rechazo.';es_CO = 'Por favor, especifique el motivo del rechazo.';tr = 'Lütfen, reddetme nedenini belirtin.';it = 'Indicare un motivo di rifiuto.';de = 'Geben Sie bitte den Grund zur Verweigerung an.'"),
			Object.Ref,
			"Object.ExecutionResult");
		
		Return;
		
	EndIf;
	
	If Write() Then
		
		WriteApprovalDetails(False);
		Notify("Write_PurchaseApproval");
		NotifyChanged(Object.Ref);
		
		ShowUserNotification(
			NStr("en = 'Not approved'; ru = 'Не утвержден';pl = 'Nie jest zatwierdzony';es_ES = 'No aprobado';es_CO = 'No aprobado';tr = 'Onaylanmadı';it = 'Non approvato';de = 'Nicht genehmigt'"),
			GetURL(Object.Ref),
			String(Object.Ref),
			PictureLib.Information32);
		
		Close();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure WriteApprovalDetails(Approved)
	
	Try
		LockDataForEdit(Object.BusinessProcess);
	Except
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot lock %1 when executing the task. %2'; ru = 'Не удалось заблокировать %1 при выполнении задачи. %2';pl = 'Nie można zablokować %1 podczas wykonywania zadania. %2';es_ES = 'No se puede bloquear %1 al ejecutar la tarea. %2';es_CO = 'No se puede bloquear %1al ejecutar la tarea. %2';tr = 'Görevi gerçekleştirirken %1 kilitlenemiyor. %2';it = 'Impossibile bloccare %1 durante l''esecuzione dell''incarico. %2';de = 'Kann %1 beim Erfüllen der Aufgabe nicht sperren. %2'"),
			Object.BusinessProcess,
			BriefErrorDescription(ErrorInfo())); 
		
	EndTry;
	
	BeginTransaction();
	
	Try
		
		SetPrivilegedMode(True);
		
		PurchaseApproval = Object.BusinessProcess.GetObject();
		PurchaseApproval.ApprovalResult		= ?(Approved, Enums.ApprovalResults.Approved, Enums.ApprovalResults.NotApproved);
		PurchaseApproval.ApprovalDetails	= Object.ExecutionResult;
		PurchaseApproval.ApprovalDate		= CurrentSessionDate();
		PurchaseApproval.Approver			= Users.AuthorizedUser();
		PurchaseApproval.Write();
		
		BusinessProcessesAndTasksServerCall.ExecuteTask(Object.Ref);
		Documents.PurchaseOrder.ChangePurchaseOrderApprovalStatus(Object.Topic, Object.BusinessProcess);
		SetPrivilegedMode(False);
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
	UnlockDataForEdit(Object.BusinessProcess);
	
EndProcedure

#EndRegion
