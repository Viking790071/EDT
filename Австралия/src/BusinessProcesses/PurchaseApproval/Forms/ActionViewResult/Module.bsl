
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InitialExecutionFlag = Object.Executed;
	ReadOnly = Object.Executed;
	
	If Not Object.Executed Then
		Object.CompletionDate = CurrentSessionDate();	
	EndIf;
	
	If TypeOf(Object.BusinessProcess) = Type("BusinessProcessRef.PurchaseApproval") Then
		BPAttributes = Common.ObjectAttributesValues(
			Object.BusinessProcess,
			"ApprovalResult, ApprovalDetails, Importance, StartDate");
		FillPropertyValues(ThisObject, BPAttributes);
		
		If BPAttributes.ApprovalResult = Enums.ApprovalResults.Approved Then
			Approved = NStr("en = 'Approved'; ru = 'Утвержден';pl = 'Zatwierdzony';es_ES = 'Aprobado';es_CO = 'Aprobado';tr = 'Onaylandı';it = 'Approvato';de = 'Genehmigt'");
		Else
			Approved = NStr("en = 'Not approved'; ru = 'Не утвержден';pl = 'Nie jest zatwierdzony';es_ES = 'No aprobado';es_CO = 'No aprobado';tr = 'Onaylanmadı';it = 'Non approvato';de = 'Nicht genehmigt'");
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Reviewed(Command)

	ClearMessages();
	
	If Write() Then
		
		ReviewedServer();
		NotifyChanged(Object.Ref);
		
		ShowUserNotification(
			NStr("en = 'Change'; ru = 'Изменить';pl = 'Zmień';es_ES = 'Cambiar';es_CO = 'Cambiar';tr = 'Değiştir';it = 'Modificare';de = 'Ändern'"),
			GetURL(Object.Ref),
			String(Object.Ref),
			PictureLib.Information32);
		
		Close();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Save(Command)

	If Write() Then
		
		NotifyChanged(Object.Ref);
		
		ShowUserNotification(
			NStr("en = 'Change'; ru = 'Изменить';pl = 'Zmień';es_ES = 'Cambiar';es_CO = 'Cambiar';tr = 'Değiştir';it = 'Modificare';de = 'Ändern'"),
			GetURL(Object.Ref),
			String(Object.Ref),
			PictureLib.Information32);
		
	EndIf;

EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure ReviewedServer()

	BusinessProcessesAndTasksServerCall.ExecuteTask(Object.Ref);
	
EndProcedure


#EndRegion


