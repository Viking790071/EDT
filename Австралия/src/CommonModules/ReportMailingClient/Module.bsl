///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Internal

// Report form command handler.
//
// Parameters:
//   Form     - ClientApplicationForm - Report form.
//   Command - FormCommand - a command that was called.
//
// Usage locations:
//   CommonForm.ReportForm.Attachable_Command().
//
Procedure CreateNewBulkEmailFromReport(Form, Command) Export
	OpenReportMailingFromReportForm(Form);
EndProcedure

// Report form command handler.
//
// Parameters:
//   Form     - ClientApplicationForm - Report form.
//   Command - FormCommand - a command that was called.
//
// Usage locations:
//   CommonForm.ReportForm.Attachable_Command().
//
Procedure AttachReportToExistingBulkEmail(Form, Command) Export
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.Items);
	FormParameters.Insert("MultipleChoice", False);
	
	OpenForm("Catalog.ReportMailings.ChoiceForm", FormParameters, Form);
EndProcedure

// Report form command handler.
//
// Parameters:
//   Form     - ClientApplicationForm - Report form.
//   Command - FormCommand - a command that was called.
//
// Usage locations:
//   CommonForm.ReportForm.Attachable_Command().
//
Procedure OpenBulkEmailsWithReport(Form, Command) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("Report", Form.ReportSettings.OptionRef);
	OpenForm("Catalog.ReportMailings.ListForm", FormParameters, Form);
	
EndProcedure

// Report form selection handler.
//
// Parameters:
//   Form             - ClientApplicationForm - Report form.
//   SelectedValue - Arbitrary     - a selection result in a subordinate form.
//   ChoiceSource    - ClientApplicationForm - a form where the choice is made.
//   Result - Boolean - True if the selection result is processed.
//
// Usage locations:
//   CommonForm.ReportForm.ChoiceProcessing().
//
Procedure ChoiceProcessingReportForm(Form, SelectedValue, ChoiceSource, Result) Export
	
	If Result = True Then
		Return;
	EndIf;
	
	If TypeOf(SelectedValue) = Type("CatalogRef.ReportMailings") Then
		
		OpenReportMailingFromReportForm(Form, SelectedValue);
		
		Result = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Generates a mailing recipients list, suggests the user to select a specific recipient or all 
//   recipients of the mailing and returns the result of the user selection.
//   
// Called from the??items form.
//
Procedure SelectRecipient(ResultHandler, Object, MultipleChoice, ReturnsMap) Export
	
	If Object.Personal = True Then
		ParametersSet = "Ref, RecipientEmailAddressKind, Personal, Author";
	Else
		ParametersSet = "Ref, RecipientEmailAddressKind, Personal, MailingRecipientType, Recipients";
	EndIf;
	
	RecipientsParameters = New Structure(ParametersSet);
	FillPropertyValues(RecipientsParameters, Object);
	ExecutionResult = ReportMailingServerCall.GenerateMailingRecipientsList(RecipientsParameters);
	
	If ExecutionResult.HadCriticalErrors Then
		QuestionToUserParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionToUserParameters.SuggestDontAskAgain = False;
		QuestionToUserParameters.Picture = PictureLib.Warning32;
		StandardSubsystemsClient.ShowQuestionToUser(Undefined, ExecutionResult.Text, 
			QuestionDialogMode.OK, QuestionToUserParameters);
		Return;
	EndIf;
	
	Recipients = ExecutionResult.Recipients;
	If Recipients.Count() = 1 Then
		Result = Recipients;
		If Not ReturnsMap Then
			For Each KeyAndValue In Recipients Do
				Result = New Structure("Recipient, MailAddress", KeyAndValue.Key, KeyAndValue.Value);
			EndDo;
		EndIf;
		ExecuteNotifyProcessing(ResultHandler, Result);
		Return;
	EndIf;
	
	PossibleRecipients = New ValueList;
	For Each KeyAndValue In Recipients Do
		PossibleRecipients.Add(KeyAndValue.Key, String(KeyAndValue.Key) +" <"+ KeyAndValue.Value +">");
	EndDo;
	If MultipleChoice Then
		PossibleRecipients.Insert(0, Undefined, NStr("ru = '???????? ??????????????????????'; en = 'To all recipients'; pl = 'Do wszystkich odbiorc??w';es_ES = 'A todos los destinatarios';es_CO = 'A todos los destinatarios';tr = 'T??m al??c??lara';it = 'A tutti i destinatari';de = 'An alle Empf??nger'"));
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ResultHandler", ResultHandler);
	AdditionalParameters.Insert("Recipients", Recipients);
	AdditionalParameters.Insert("ReturnsMap", ReturnsMap);
	
	Handler = New NotifyDescription("SelectRecipientEnd", ThisObject, AdditionalParameters);
	
	PossibleRecipients.ShowChooseItem(Handler, NStr("ru = '?????????? ????????????????????'; en = 'Select recipient'; pl = 'Wybierz odbiorc??';es_ES = 'Seleccionar el destinatario';es_CO = 'Seleccionar el destinatario';tr = 'Al??c?? se??';it = 'Selezionare destinatario';de = 'Empf??nger w??hlen'"));
EndProcedure

// SelectRecipient procedure execution result handler.
Procedure SelectRecipientEnd(SelectedItem, AdditionalParameters) Export
	If SelectedItem = Undefined Then
		Result = Undefined;
	Else
		If AdditionalParameters.ReturnsMap Then
			If SelectedItem.Value = Undefined Then
				Result = AdditionalParameters.Recipients;
			Else
				Result = New Map;
				Result.Insert(SelectedItem.Value, AdditionalParameters.Recipients[SelectedItem.Value]);
			EndIf;
		Else
			Result = New Structure("Recipient, MailAddress", SelectedItem.Value, AdditionalParameters.Recipients[SelectedItem.Value]);
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.ResultHandler, Result);
EndProcedure

// Executes mailing in the background.
Procedure ExecuteNow(Parameters) Export
	Handler = New NotifyDescription("ExecuteNowInBackground", ThisObject, Parameters);
	If Parameters.IsItemForm Then
		Object = Parameters.Form.Object;
		If Not Object.Prepared Then
			ShowMessageBox(, NStr("ru = '???????????????? ???? ????????????????????????'; en = 'Bulk email is not prepared'; pl = 'Masowa wysy??ka e-mail nie jest przygotowana';es_ES = 'El newsletter no est?? listo';es_CO = 'El newsletter no est?? listo';tr = 'Toplu e-posta haz??rlanmad??';it = 'L''email multipla non ?? preparata';de = 'Bulk Mail ist nicht bereitet'"));
			Return;
		EndIf;
		If Object.UseEmail Then
			SelectRecipient(Handler, Parameters.Form.Object, True, True);
			Return;
		EndIf;
	EndIf;
	ExecuteNotifyProcessing(Handler, Undefined);
EndProcedure

// Runs background job, it is called when all parameters are ready.
Procedure ExecuteNowInBackground(Recipients, Parameters) Export
	PreliminarySettings = Undefined;
	If Parameters.IsItemForm Then
		If Parameters.Form.Object.UseEmail Then
			If Recipients = Undefined Then
				Return;
			EndIf;
			PreliminarySettings = New Structure("Recipients", Recipients);
		EndIf;
		StateText = NStr("ru = '?????????????????????? ???????????????? ??????????????.'; en = 'Sending reports.'; pl = 'Wysy??anie raport??w.';es_ES = 'Enviar informes.';es_CO = 'Enviar informes.';tr = 'Raporlar g??nderiliyor.';it = 'Invio di report.';de = 'Berichte senden.'");
	Else
		StateText = NStr("ru = '?????????????????????? ???????????????? ??????????????.'; en = 'Sending reports.'; pl = 'Wysy??anie raport??w.';es_ES = 'Enviar informes.';es_CO = 'Enviar informes.';tr = 'Raporlar g??nderiliyor.';it = 'Invio di report.';de = 'Berichte senden.'");
	EndIf;
	
	MethodParameters = New Structure;
	MethodParameters.Insert("MailingArray", Parameters.MailingArray);
	MethodParameters.Insert("PreliminarySettings", PreliminarySettings);
	
	Job = ReportMailingServerCall.RunBackgroundJob(MethodParameters, Parameters.Form.UUID);
	
	WaitSettings = TimeConsumingOperationsClient.IdleParameters(Parameters.Form);
	WaitSettings.OutputIdleWindow = True;
	WaitSettings.MessageText = StateText;
	
	Handler = New NotifyDescription("ExecuteNowInBackgroundEnd", ThisObject, Parameters);
	TimeConsumingOperationsClient.WaitForCompletion(Job, Handler, WaitSettings);
	
EndProcedure

// Accepts the background job result.
Procedure ExecuteNowInBackgroundEnd(Job, Parameters) Export
	
	If Job = Undefined Then
		Return; // Canceled.
	EndIf;
	
	If Job.Status = "Completed" Then
		Result = GetFromTempStorage(Job.ResultAddress);
		MailingNumber = Result.BulkEmails.Count();
		If MailingNumber > 0 Then
			NotifyChanged(?(MailingNumber > 1, Type("CatalogRef.ReportMailings"), Result.BulkEmails[0]));
		EndIf;
		ShowUserNotification(,, Result.Text, PictureLib.ReportMailing, UserNotificationStatus.Information);
		
	Else
		Raise NStr("ru = '???? ?????????????? ?????????????????? ???????????????? ??????????????:'; en = 'Cannot mail reports:'; pl = 'Nie mo??na wys??a?? raport??w:';es_ES = 'No se puede enviar informes por correo:';es_CO = 'No se puede enviar informes por correo:';tr = 'Raporlar g??nderilemiyor:';it = 'Impossibile inviare report:';de = 'Kann keine Berichte senden:'")
			+ Chars.LF + Job.BriefErrorPresentation;
	EndIf;
	
EndProcedure

// Opens report mailing from the report form.
//
// Parameters:
//   Form - ClientApplicationForm - Report form.
//   Ref - CatalogRef.ReportsMailing - optional. Report mailing reference.
//
Procedure OpenReportMailingFromReportForm(Form, Ref = Undefined)
	ReportSettings = Form.ReportSettings;
	ReportOptionMode = (TypeOf(Form.CurrentVariantKey) = Type("String") AND Not IsBlankString(Form.CurrentVariantKey));
	
	ReportsParametersRow = New Structure("ReportFullName, VariantKey, OptionRef, Settings");
	ReportsParametersRow.ReportFullName = ReportSettings.FullName;
	ReportsParametersRow.VariantKey   = Form.CurrentVariantKey;
	ReportsParametersRow.OptionRef  = ReportSettings.OptionRef;
	If ReportOptionMode Then
		ReportsParametersRow.Settings = Form.Report.SettingsComposer.UserSettings;
	EndIf;
	
	ReportsToAttach = New Array;
	ReportsToAttach.Add(ReportsParametersRow);
	
	FormParameters = New Structure;
	FormParameters.Insert("ReportsToAttach", ReportsToAttach);
	If Ref <> Undefined Then
		FormParameters.Insert("Key", Ref);
	EndIf;
	
	OpenForm("Catalog.ReportMailings.ObjectForm", FormParameters, , String(Form.UUID) + ".OpenReportsMailing");
	
EndProcedure

// Returns set of scheduled job schedules filling templates.
Function ScheduleFillingOptionsList() Export
	
	VariantList = New ValueList;
	VariantList.Add(1, NStr("ru = '???????????? ????????'; en = 'Every day'; pl = 'Codziennie';es_ES = 'Cada d??a';es_CO = 'Cada d??a';tr = 'Her g??n';it = 'Ogni giorno';de = 'Jeden Tag'"));
	VariantList.Add(2, NStr("ru = '???????????? ???????????? ????????'; en = 'Every second day'; pl = 'Co drugi dzie??';es_ES = 'Cada dos d??as';es_CO = 'Cada dos d??as';tr = '??ki g??nde bir';it = 'Ogni due giorni';de = 'Jeden zweiten Tag'"));
	VariantList.Add(3, NStr("ru = '???????????? ?????????????????? ????????'; en = 'Every fourth day'; pl = 'Co czwarty dzie??';es_ES = 'Cada cuatro d??as';es_CO = 'Cada cuatro d??as';tr = 'D??rt g??nde bir';it = 'Ogni quattro giorni';de = 'Jeden vierten Tag'"));
	VariantList.Add(4, NStr("ru = '???? ????????????'; en = 'On weekdays'; pl = 'W dni powszednie';es_ES = 'Entre semana';es_CO = 'Entre semana';tr = 'Hafta i??i';it = 'Nei giorni feriali';de = 'An Werktagen'"));
	VariantList.Add(5, NStr("ru = '???? ????????????????'; en = 'On weekends'; pl = 'W weekendy';es_ES = 'Los fines de semana';es_CO = 'Los fines de semana';tr = 'Hafta sonu';it = 'Nei giorni festivi';de = 'An Wochenenden'"));
	VariantList.Add(6, NStr("ru = '???? ??????????????????????????'; en = 'On Mondays'; pl = 'W poniedzia??ki';es_ES = 'Los lunes';es_CO = 'Los lunes';tr = 'Pazartesileri';it = 'Ogni luned??';de = 'Montags'"));
	VariantList.Add(7, NStr("ru = '???? ????????????????'; en = 'On Fridays'; pl = 'W pi??tki';es_ES = 'Los viernes';es_CO = 'Los viernes';tr = 'Cumalar??';it = 'Ogni venerd??';de = 'Freitags'"));
	VariantList.Add(8, NStr("ru = '???? ????????????????????????'; en = 'On Sundays'; pl = 'W niedziele';es_ES = 'Los domingos';es_CO = 'Los domingos';tr = 'Pazarlar??';it = 'Ogni domenica';de = 'Sonntags'"));
	VariantList.Add(9, NStr("ru = '?? ???????????? ???????? ????????????'; en = 'On the first day of the month'; pl = 'Pierwszego dnia miesi??ca';es_ES = 'El primer d??a del mes';es_CO = 'El primer d??a del mes';tr = 'Ay??n ilk g??n??nde';it = 'Il primo giorno del mese';de = 'Am ersten Monatstag'"));
	VariantList.Add(10, NStr("ru = '?? ?????????????????? ???????? ????????????'; en = 'On the last day of the month'; pl = 'Ostatniego dnia miesi??ca';es_ES = 'El ??ltimo d??a del mes';es_CO = 'El ??ltimo d??a del mes';tr = 'Ay??n son g??n??nde';it = 'L''ultimo giorno del mese';de = 'Am letzten Monatstag'"));
	VariantList.Add(11, NStr("ru = '???????????? ?????????????? ???????????????? ??????????'; en = 'Every quarter on the 10th'; pl = 'Co kwarta?? 10-go';es_ES = 'Cada trimestre el d??a 10';es_CO = 'Cada trimestre el d??a 10';tr = 'Her ??eyre??in 10''unda';it = 'Il 10 di ogni trimestre';de = 'Jedes Quartals am 10.'"));
	VariantList.Add(12, NStr("ru = '????????????...'; en = 'Other...'; pl = 'Inne...';es_ES = 'Otro...';es_CO = 'Otro...';tr = 'Di??er...';it = 'Altro';de = 'Sonstiges...'"));
	
	Return VariantList;
EndFunction

// Parses the??FTP address string into the Username, Password, Port and Directory.
//   Detailed - see RFC 1738 (http://tools.ietf.org/html/rfc1738#section-3.1). 
//   Template: ftp://<user>:<password>@<host>:<port>/<url-path>.
//   Fragments <user>:<password>@, :<password>, :<port> and /<url-path> can be absent.
//
// Parameters:
//   FTPAddress - String - a full path to the ftp resource.
//
// Returns:
//   Structure - Result - Structure - Parsing result for the full path.
//       * Username - String - ftp user name.
//       * Password - String - ftp user password.
//       * Server - String - a server name.
//       * Port - Number - server port. 21 by default.
//       * Directory - String - path to the directory at the server. The first character is always /.
//
Function ParseFTPAddress(FullFTPAddress) Export
	
	Result = New Structure;
	Result.Insert("Username", "");
	Result.Insert("Password", "");
	Result.Insert("Server", "");
	Result.Insert("Port", 21);
	Result.Insert("Directory", "/");
	
	FTPAddress = FullFTPAddress;
	
	// Cut ftp://.
	Pos = StrFind(FTPAddress, "://");
	If Pos > 0 Then
		FTPAddress = Mid(FTPAddress, Pos + 3);
	EndIf;
	
	// Directory.
	Pos = StrFind(FTPAddress, "/");
	If Pos > 0 Then
		Result.Directory = Mid(FTPAddress, Pos);
		FTPAddress = Left(FTPAddress, Pos - 1);
	EndIf;
	
	// Username and password.
	Pos = StrFind(FTPAddress, "@");
	If Pos > 0 Then
		UsernamePassword = Left(FTPAddress, Pos - 1);
		FTPAddress = Mid(FTPAddress, Pos + 1);
		
		Pos = StrFind(UsernamePassword, ":");
		If Pos > 0 Then
			Result.Username = Left(UsernamePassword, Pos - 1);
			Result.Password = Mid(UsernamePassword, Pos + 1);
		Else
			Result.Username = UsernamePassword;
		EndIf;
	EndIf;
	
	// Server and port.
	Pos = StrFind(FTPAddress, ":");
	If Pos > 0 Then
		
		Result.Server = Left(FTPAddress, Pos - 1);
		
		NumberType = New TypeDescription("Number");
		Port     = NumberType.AdjustValue(Mid(FTPAddress, Pos + 1));
		Result.Port = ?(Port > 0, Port, Result.Port);
		
	Else
		
		Result.Server = FTPAddress;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion
