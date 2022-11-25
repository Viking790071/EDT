
#Region Variables

&AtClient
Var IdleInterval;
&AtClient
Var FormClosing;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	MessageText = NStr("ru = 'Пожалуйста, подождите...'; en = 'Please wait...'; pl = 'Proszę czekać…';es_ES = 'Por favor, espere...';es_CO = 'Por favor, espere...';tr = 'Lütfen bekleyin...';it = 'Si prega di attendere...';de = 'Bitte warten...'");
	If Not IsBlankString(Parameters.MessageText) Then
		MessageText = Parameters.MessageText + Chars.LF + MessageText;
		Items.TimeConsumingOperationNoteTextDecoration.Title = MessageText;
	EndIf;
	
	If ValueIsFilled(Parameters.JobID) Then
		JobID = Parameters.JobID;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Parameters.OutputIdleWindow Then
		IdleInterval = ?(Parameters.Interval <> 0, Parameters.Interval, 1);
		AttachIdleHandler("Attachable_CheckJobExecution", IdleInterval, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Status <> "Running" Then
		Return;
	EndIf;
	
	Cancel = True;
	If Exit Then
		Return;
	EndIf;
	
	AttachIdleHandler("Attachable_CancelJob", 0.1, True);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	If Status <> "Running" Then
		Return;
	EndIf;
	
	CancelJobExecution();
	
EndProcedure

#EndRegion

#Region Commands

&AtClient
Procedure Cancel(Command)
	
	FormClosing = True;
	Attachable_CheckJobExecution(); // Checking whether the job is completed.
	If Status = "Canceled" Then
		Status = Undefined;
		Close(ExecutionResult(Undefined));
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Job = CheckJobCompletion(FormClosing);
	Status = Job.Status;
	
	If Job.Progress <> Undefined Then
		ProgressString = ProgressString(Job.Progress);
		If Not IsBlankString(ProgressString) Then
			Items.TimeConsumingOperationNoteTextDecoration.Title = MessageText + " " + ProgressString;
		EndIf;
	EndIf;
	If Job.Messages <> Undefined AND FormOwner <> Undefined Then
		TargetID = FormOwner.UUID;
		For each UserMessage In Job.Messages Do
			UserMessage.TargetID = TargetID;
			UserMessage.Message();
		EndDo;
	EndIf;
	
	If Status = "Completed" Then
		
		ShowNotification();
		If ReturnResultToChoiceProcessing() Then
			NotifyChoice(Job.Result);
			Return;
		EndIf;
		Close(ExecutionResult(Job));
		Return;
		
	ElsIf Status = "Error" Then
		
		Close(ExecutionResult(Job));
		If ReturnResultToChoiceProcessing() Then
			Raise Job.BriefErrorPresentation;
		EndIf;
		Return;
		
	EndIf;
	
	If Parameters.OutputIdleWindow Then
		If Parameters.Interval = 0 Then
			IdleInterval = IdleInterval * 1.4;
			If IdleInterval > 15 Then
				IdleInterval = 15;
			EndIf;
		EndIf;
		AttachIdleHandler("Attachable_CheckJobExecution", IdleInterval, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_CancelJob()
	
	Cancel(Undefined);
	
EndProcedure

&AtClient
Procedure ShowNotification()
	
	If Parameters.UserNotification = Undefined Or Not Parameters.UserNotification.Show Then
		Return;
	EndIf;
	
	Notification = Parameters.UserNotification;
	
	NotificationURL = Notification.URL;
	If NotificationURL = Undefined AND FormOwner <> Undefined AND FormOwner.Window <> Undefined Then
		NotificationURL = FormOwner.Window.GetURL();
	EndIf;
	NotificationComment = Notification.Explanation;
	If NotificationComment = Undefined AND FormOwner <> Undefined AND FormOwner.Window <> Undefined Then
		NotificationComment = FormOwner.Window.Caption;
	EndIf;
	
	ShowUserNotification(?(Notification.Text <> Undefined, Notification.Text, NStr("ru = 'Действие выполнено'; en = 'Operation completed.'; pl = 'Działanie zakończone';es_ES = 'Acción realizada';es_CO = 'Acción realizada';tr = 'Eylem tamamlandı';it = 'Operazione completata.';de = 'Operation abgeschlossen.'")), 
		NotificationURL, NotificationComment);

EndProcedure

&AtServer
Function CheckJobCompletion(FormClosing)
	
	Job = TimeConsumingOperations.ActionCompleted(JobID, False, Parameters.OutputProgressBar,
		Parameters.OutputMessages);
	
	If Parameters.MustReceiveResult Then
		If Job.Status = "Completed" Then
			Job.Insert("Result", GetFromTempStorage(Parameters.ResultAddress));
		Else
			Job.Insert("Result", Undefined);
		EndIf;
	EndIf;
	
	If FormClosing = True Then
		CancelJobExecution();
		Job.Status = "Canceled";
	EndIf;	
	
	Return Job;
	
EndFunction

&AtClient
Function ProgressString(Progress)
	
	Result = "";
	If Progress = Undefined Then
		Return Result;
	EndIf;
	
	Percent = 0;
	If Progress.Property("Percent", Percent) Then
		Result = String(Percent) + "%";
	EndIf;
	Text = 0;
	If Progress.Property("Text", Text) Then
		If Not IsBlankString(Result) Then
			Result = Result + " (" + Text + ")";
		Else
			Result = Text;
		EndIf;
	EndIf;

	Return Result;
	
EndFunction

&AtClient
Function ExecutionResult(Job)
	
	If Job = Undefined Then
		Return Undefined;
	EndIf;
	
	Result = New Structure;
	Result.Insert("Status", Job.Status);
	Result.Insert("ResultAddress", Parameters.ResultAddress);
	Result.Insert("AdditionalResultAddress", Parameters.AdditionalResultAddress);
	Result.Insert("BriefErrorPresentation", Job.BriefErrorPresentation);
	Result.Insert("DetailedErrorPresentation", Job.DetailedErrorPresentation);
	Result.Insert("Messages", Job.Messages);
	
	If Parameters.MustReceiveResult Then
		Result.Insert("Result", Job.Result);
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Function ReturnResultToChoiceProcessing()
	Return OnCloseNotifyDescription = Undefined
		AND Parameters.MustReceiveResult
		AND TypeOf(FormOwner) = Type("ClientApplicationForm");
EndFunction

&AtServer
Procedure CancelJobExecution()
	
	TimeConsumingOperations.CancelJobExecution(JobID);
	
EndProcedure

#EndRegion
