
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns object attributes allowed to be edited using batch attribute change data processor.
// 
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("Author");
	Result.Add("Importance");
	Result.Add("Performer");
	Result.Add("CheckExecution");
	Result.Add("Supervisor");
	Result.Add("DueDate");
	Result.Add("VerificationDueDate");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectsModification

// StandardSubsystems.BusinessProcessesAndTasks

// Gets a structure with description of a task execution form.
// The function is called when opening the task execution form.
//
// Parameters:
//   TaskRef                - TaskRef.PerformerTask - a task.
//   BusinessProcessRoutePoint - BusinessProcessRoutePointRef - a route point.
//
// Returns:
//   Structure   - a structure with description of the task execution form.
//                 Key FormName contains the form name that is passed to the OpenForm() context method.
//                 Key FormOptions contains the form parameters.
//
Function TaskExecutionForm(TaskRef, BusinessProcessRoutePoint) Export
	
	Result = New Structure;
	Result.Insert("FormParameters", New Structure("Key", TaskRef));
	Result.Insert("FormName", "BusinessProcess.PurchaseApproval.Form.Action" + BusinessProcessRoutePoint.Name);
	Return Result;
	
EndFunction

// The function is called when forwarding a task.
//
// Parameters:
//   TaskRef  - TaskRef.PerformerTask - a forwarded task.
//   NewTaskRef  - TaskRef.PerformerTask - a task for a new assignee.
//
Procedure OnForwardTask(TaskRef, NewTaskRef) Export
	
	// ForwardTasks calling function.
	BusinessProcessObject = TaskRef.BusinessProcess.GetObject();
	LockDataForEdit(BusinessProcessObject.Ref);
	BusinessProcessObject.ExecutionResult = ExecutionResultOnForward(TaskRef) 
		+ BusinessProcessObject.ExecutionResult;
	SetPrivilegedMode(True);
	BusinessProcessObject.Write();
	
EndProcedure

// The function is called when a task is executed from a list form.
//
// Parameters:
//   TaskRef  - TaskRef.PerformerTask - a task.
//   BusinessProcessRef - BusinessProcessRef - a business process for which the TaskRef task is generated.
//   BusinessProcessRoutePoint - BusinessProcessRoutePointRef - a route point.
//
Procedure DefaultCompletionHandler(TaskRef, BusinessProcessRef, BusinessProcessRoutePoint) Export
	
	IsRoutePointApprove = (BusinessProcessRoutePoint = BusinessProcesses.PurchaseApproval.RoutePoints.Approve);
	IsRoutePointViewResult = (BusinessProcessRoutePoint = BusinessProcesses.PurchaseApproval.RoutePoints.ViewResult);
	If Not IsRoutePointApprove AND Not IsRoutePointViewResult Then
		Return;
	EndIf;
	
	// Setting default values for batch task execution.
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockBusinessProcesses(BusinessProcessRef);
		
		SetPrivilegedMode(True);
		JobObject = BusinessProcessRef.GetObject();
		LockDataForEdit(JobObject.Ref);
		
		If IsRoutePointApprove Then
			JobObject.ApprovalResult = Enums.ApprovalResults.Approved;
		EndIf;
		JobObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;	
	
EndProcedure	

// End StandardSubsystems.BusinessProcessesAndTasks

// StandardSubsystems.AttachableCommands

// Defined the list of commands for creating on the basis.
//
// Parameters:
//  GenerationCommands - ValueTable - see GenerationOverridable.BeforeAddGenerationCommands. 
//  Parameters - Structure - see GenerationOverridable.BeforeAddGenerationCommands. 
//
Procedure AddGenerationCommands(GenerationCommands, Parameters) Export
	
EndProcedure

// Use this procedure in the AddGenerationCommands procedure of other object manager modules.
// Adds this object to the list of object generation commands.
//
// Parameters:
//  GenerationCommands - ValueTable - see GenerationOverridable.BeforeAddGenerationCommands. 
//
// Returns:
//  ValueTableRow, Undefined - details of the added command.
//
Function AddGenerateCommand(GenerationCommands) Export
	
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleGeneration = Common.CommonModule("Generate");
		Return ModuleGeneration.AddGenerationCommand(GenerationCommands, Metadata.BusinessProcesses.Job);
	EndIf;
	
	Return Undefined;
	
EndFunction

// End StandardSubsystems.AttachableCommands

#EndRegion

Procedure ChangeApprovalSettingsInCatalogs(Parameters, ResultAddress = "") Export

	ApprovePurchaseOrders = Parameters.ApprovePurchaseOrders;
	LimitWithoutApproval = Parameters.LimitWithoutApproval;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	""Counterperty"" AS CatalogName,
	|	Counterparties.Ref AS Ref
	|FROM
	|	Catalog.Counterparties AS Counterparties
	|WHERE
	|	Counterparties.Supplier
	|	AND NOT Counterparties.DeletionMark
	|	AND NOT Counterparties.DoOperationsByContracts
	|	AND (Counterparties.ApprovePurchaseOrders <> &ApprovePurchaseOrders
	|			OR Counterparties.LimitWithoutApproval <> &LimitWithoutApproval)
	|
	|UNION ALL
	|
	|SELECT
	|	""Contract"",
	|	CounterpartyContracts.Ref
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|WHERE
	|	CounterpartyContracts.ContractKind = VALUE(Enum.ContractType.WithVendor)
	|	AND NOT CounterpartyContracts.DeletionMark
	|	AND (CounterpartyContracts.ApprovePurchaseOrders <> &ApprovePurchaseOrders
	|			OR CounterpartyContracts.LimitWithoutApproval <> &LimitWithoutApproval)";
	
	Query.SetParameter("ApprovePurchaseOrders", ApprovePurchaseOrders);
	Query.SetParameter("LimitWithoutApproval", LimitWithoutApproval);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	BeginTransaction();
	
	Try
		
		While Selection.Next() Do
			
			CatalogObject = Selection.Ref.GetObject();
			CatalogObject.ApprovePurchaseOrders = ApprovePurchaseOrders;
			CatalogObject.LimitWithoutApproval = LimitWithoutApproval;
			CatalogObject.Write();
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		CatalogName = ?(Selection.CatalogName = "Counterparty", NStr("en = 'counterparty'; ru = 'контрагент';pl = 'kontrahent';es_ES = 'contraparte';es_CO = 'contraparte';tr = 'cari hesap';it = 'controparte';de = 'Geschäftspartner'"), NStr("en = 'contract'; ru = 'договор';pl = 'kontrakt';es_ES = 'contrato';es_CO = 'contrato';tr = 'sözleşme';it = 'contratto';de = 'vertrag'"));
		
		EventName = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Purchase orders approval. %1 change'; ru = 'Утверждение заказов поставщику. Изменение %1';pl = 'Zatwierdzono zamówienie zakupu. %1 zmiany';es_ES = 'Aprobar la orden de compra. %1 cambio';es_CO = 'Aprobar la orden de compra.%1 cambio';tr = 'Satın alma siparişi onayı. %1 değiştir';it = 'Approvazione ordine di acquisto. %1 modifica';de = 'Genehmigung der Bestellung an Lieferanten. %1 Ändern'"), CatalogName, CommonClientServer.DefaultLanguageCode());
		
		WriteLogEvent(EventName, EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot change the %1.'; ru = 'Не удалось изменить %1.';pl = 'Nie można zmienić %1.';es_ES = 'No se ha podido cambiar el %1.';es_CO = 'No se ha podido cambiar el %1.';tr = '%1 değiştirilemedi.';it = 'Impossibile modificare %1.';de = 'Kann %1 nicht ändern.'"), CatalogName);
		
	EndTry;
	
EndProcedure

Procedure InitializePerformerRoles() Export
	
	RoleObject = Catalogs.PerformerRoles.EmployeeApprovingPurchases.GetObject();
	RoleObject.UsedWithoutAddressingObjects = True;
	RoleObject.Write();
	
EndProcedure

#EndRegion

#Region Private

Function ExecutionResultOnForward(Val TaskRef)
	
	StringFormat = "%1, %2 " + NStr("en = 'redirected the task'; ru = 'перенаправил(а) задачу';pl = 'przekierowano zadanie';es_ES = 'redirigir la tarea';es_CO = 'redirigir la tarea';tr = 'görev yeniden yönlendirildi';it = 'incarico reindirizzato';de = 'die Aufgabe weitergeleitet'") + ":
		|%3
		|";
	
	Comment = TrimAll(TaskRef.ExecutionResult);
	Comment = ?(IsBlankString(Comment), "", Comment + Chars.LF);
	Result = StringFunctionsClientServer.SubstituteParametersToString(
		StringFormat,
		TaskRef.CompletionDate,
		TaskRef.Performer,
		Comment);
	Return Result;

EndFunction

#EndRegion

#EndIf