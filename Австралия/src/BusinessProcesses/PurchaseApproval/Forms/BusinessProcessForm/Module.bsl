
#Region FormEventHandlers

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	CalculateCurrentState();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If CurrentObject.Started Then
		
		CalculateCurrentState();
		Task = GetTask();
		
		If Task <> Undefined Then
			TaskObject = Task.GetObject();
			TaskObject.Details = Object.Description;
			TaskObject.Write();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_PurchaseApproval", New Structure, Object.Ref);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_PerformerTask"
		And Not Modified Then 
		Read();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CalculateCurrentState()
	
	If Object.Started Then
		If Object.ApprovalResult = Enums.ApprovalResults.Approved Then
			CurrentState = NStr("en = 'Approved'; ru = 'Утвержден';pl = 'Zatwierdzony';es_ES = 'Aprobado';es_CO = 'Aprobado';tr = 'Onaylandı';it = 'Approvato';de = 'Genehmigt'");
		ElsIf Object.ApprovalResult = Enums.ApprovalResults.NotApproved Then
			CurrentState = NStr("en = 'Rejected'; ru = 'Отклонен';pl = 'Odrzucono';es_ES = 'Rechazado';es_CO = 'Rechazado';tr = 'Reddedildi';it = 'Rifiutato';de = 'Abgelehnt'");
		Else
			CurrentState = NStr("en = 'Pending approval'; ru = 'Ожидает утверждения';pl = 'Oczekuje na zatwierdzenie';es_ES = 'Pendiente de aprovación';es_CO = 'Pendiente de aprovación';tr = 'Onay bekliyor';it = 'Approvazione pendente';de = 'Anstehende Genehmigung'");
		EndIf;
	Else
		CurrentState = "";
	EndIf;
	
EndProcedure

&AtServer
Function GetTask()
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	PerformerTask.Ref AS Ref
	|FROM
	|	Task.PerformerTask AS PerformerTask
	|WHERE
	|	NOT PerformerTask.Executed
	|	AND PerformerTask.BusinessProcess = &BusinessProcess";
	
	Query.SetParameter("BusinessProcess", Object.Ref);
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	If Selection.Next() Then
		Return Selection.Ref;
	EndIf;
	
EndFunction

#EndRegion

