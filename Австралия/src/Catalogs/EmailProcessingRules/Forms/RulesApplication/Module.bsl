///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Parameters.Account) Or Parameters.Account.IsEmpty() Then
		Cancel = True;
		Return;
	EndIf;
		
	Account = Parameters.Account;
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	EmailProcessingRules.Ref AS Rule,
	|	FALSE AS Apply,
	|	EmailProcessingRules.FilterPresentation,
	|	EmailProcessingRules.PutInFolder
	|FROM
	|	Catalog.EmailProcessingRules AS EmailProcessingRules
	|WHERE
	|	EmailProcessingRules.Owner = &Owner
	|	AND (NOT EmailProcessingRules.DeletionMark)
	|
	|ORDER BY
	|	EmailProcessingRules.AddlOrderingAttribute";
	
	Query.SetParameter("Owner", Parameters.Account);
	Query.SetParameter("Incoming", NStr("ru = 'Входящие'; en = 'Incoming messages'; pl = 'Wiadomości przychodzące';es_ES = 'Mensajes entrantes';es_CO = 'Mensajes entrantes';tr = 'Gelen iletiler';it = 'Messaggi in entrata';de = 'Eingehende Nachrichten'"));
	
	Result = Query.Execute();
	If NOT Result.IsEmpty() Then
		Rules.Load(Result.Unload());
	EndIf;
	
	If ValueIsFilled(Parameters.ForEmailsInFolder) Then
		ForEmailsInFolder = Parameters.ForEmailsInFolder;
	Else 
		
		Query.Text = "
		|SELECT
		|	EmailMessageFolders.Ref
		|FROM
		|	Catalog.EmailMessageFolders AS EmailMessageFolders
		|WHERE
		|	EmailMessageFolders.PredefinedFolder
		|	AND EmailMessageFolders.Owner = &Owner
		|	AND EmailMessageFolders.Description = &Incoming";
		
		Result = Query.Execute();
		If NOT Result.IsEmpty() Then
			Selection = Result.Select();
			Selection.Next();
			ForEmailsInFolder = Selection.Ref;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Apply(Command)
	
	ClearMessages();
	
	AtLeastOneRuleSelected = False;
	Cancel = False;
	
	For each Rule In Rules Do
		
		If Rule.Apply Then
			AtLeastOneRuleSelected = True;
			Break;
		EndIf;
		
	EndDo;
	
	If Not AtLeastOneRuleSelected Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Необходимо выбрать хотя бы одно правило для применения'; en = 'Please select at least one rule.'; pl = 'Wybierz co najmniej jedną regułę.';es_ES = 'Por favor, seleccione al menos una regla.';es_CO = 'Por favor, seleccione al menos una regla.';tr = 'Lütfen, en az bir kural seçin.';it = 'Selezionare almeno una regola.';de = 'Bitte wählen Sie zumindest eine Regel aus.'"),,"List");
		Cancel = True;
	EndIf;
	
	If ForEmailsInFolder.IsEmpty() Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Не выбрана папка к письмам которой будут применены правила'; en = 'Please select a folder.'; pl = 'Wybierz folder.';es_ES = 'Por favor, seleccione una carpeta.';es_CO = 'Por favor, seleccione una carpeta.';tr = 'Lütfen, klasör seçin.';it = 'Selezionare una cartella.';de = 'Bitte wählen Sie einen Ordner aus.'"),,"ForEmailsInFolder");
		Cancel = True;
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	TimeConsumingOperation = ApplyRulesAtServer();
	If TimeConsumingOperation = Undefined Then
		Return;
	EndIf;
	
	If TimeConsumingOperation.Status = "Completed" Then
		Notify("MessageProcessingRulesApplied");
	ElsIf TimeConsumingOperation.Status = "Running" Then
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		CompletionNotification = New NotifyDescription("ApplyRulesCompletion", ThisObject);
		TimeConsumingOperationsClient.WaitForCompletion(TimeConsumingOperation, CompletionNotification, IdleParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure ApplyAllRules(Command)
	
	For each Row In Rules Do
		Row.Apply = True;
	EndDo;
	
EndProcedure

&AtClient
Procedure DontApplyAllRules(Command)
	
	For each Row In Rules Do
		Row.Apply = False;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function ApplyRulesAtServer()
	
	ProcedureParameters = New Structure;
	
	ProcedureParameters.Insert("RulesTable", Rules.Unload());
	ProcedureParameters.Insert("ForEmailsInFolder", ForEmailsInFolder);
	ProcedureParameters.Insert("IncludeSubordinateSubsystems", IncludeSubordinateSubsystems);
	ProcedureParameters.Insert("Account", Account);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("ru = 'Применение правил'; en = 'Apply rules'; pl = 'Zastosuj reguły';es_ES = 'Aplicar las reglas';es_CO = 'Aplicar las reglas';tr = 'Kuralları uygula';it = 'Applicare regole';de = 'Regeln verwenden'") + " ";
	
	TimeConsumingOperation = TimeConsumingOperations.ExecuteInBackground(
			"Catalogs.EmailProcessingRules.ApplyRules",
			ProcedureParameters,
			ExecutionParameters);
			
	If TimeConsumingOperation.Status = "Completed" Then
		ImportResult(TimeConsumingOperation.ResultAddress);
	EndIf;
	
	Return TimeConsumingOperation;
	
EndFunction

&AtClient
Procedure ApplyRulesCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	ElsIf Result.Status = "Error" Then
		Raise Result.BriefErrorPresentation;
	ElsIf Result.Status = "Completed" Then
		ImportResult(Result.ResultAddress);
		Notify("MessageProcessingRulesApplied");
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportResult(ResultAddress)
	
	Result = GetFromTempStorage(ResultAddress);
	If TypeOf(Result) = Type("String")
		AND ValueIsFilled(Result) Then 
		CommonClientServer.MessageToUser(Result);
	EndIf;
	
EndProcedure

#EndRegion
