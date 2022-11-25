#Region Variables

&AtClient
Var CompletedStatus;

&AtClient
Var IdleHandlerParameters;

&AtClient
Var OpenStatus;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	FillPropertyValues(Items.StatusOfLastExchange, ExchangeWithProManageServerCall.GetStatusOfLastExchange());
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	DriveClientServer.SetListFilterItem(
		List, "StructuralUnit", FilterStructuralUnit, ValueIsFilled(FilterStructuralUnit));
	DriveClientServer.SetListFilterItem(List, "Products", FilterProducts, ValueIsFilled(FilterProducts));
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(List, "Status", FilterStatus, ValueIsFilled(FilterStatus));
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	CompletedStatus = PredefinedValue("Enum.ManufacturingOperationStatuses.Completed");
	OpenStatus = PredefinedValue("Enum.ManufacturingOperationStatuses.Open");
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshProductionOrderQueue" Then
		Items.List.Refresh();
	EndIf;
	
	If EventName = "ExchangeWithProManage" Then
		FillPropertyValues(Items.StatusOfLastExchange, ExchangeWithProManageServerCall.GetStatusOfLastExchange());
	EndIf;
	
	If EventName = "DocumentWIPGenerationVisibility" Then
		DriveClient.DocumentWIPGenerationVisibility(Items, Items.List, 
			New Structure("CompletedStatus, OpenStatus", CompletedStatus, OpenStatus));
	EndIf;
		
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterStructuralUnitOnChange(Item)
	DriveClientServer.SetListFilterItem(
		List, "StructuralUnit", FilterStructuralUnit, ValueIsFilled(FilterStructuralUnit));
EndProcedure

&AtClient
Procedure FilterProductsOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "Products", FilterProducts, ValueIsFilled(FilterProducts));
EndProcedure

&AtClient
Procedure FilterStatusOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "Status", FilterStatus, ValueIsFilled(FilterStatus));
EndProcedure

&AtClient
Procedure FilterProManageStatusOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "ProManageStatus", FilterProManageStatus, ValueIsFilled(FilterProManageStatus));
EndProcedure

&AtClient
Procedure FilterCompanyOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	DriveClient.DocumentWIPGenerationVisibility(Items, Item, 
		New Structure("CompletedStatus, OpenStatus", CompletedStatus, OpenStatus));

	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure RunSync(Command)
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Data exchange with ProManage started on %1.'; ru = 'Обмен данными с ProManage начался %1.';pl = 'Wymiana danych z ProManage została rozpoczęta %1.';es_ES = 'Intercambio de datos con ProManage comenzado el %1.';es_CO = 'Intercambio de datos con ProManage comenzado el %1.';tr = 'ProManage ile veri değişimi başlangıcı: %1.';it = 'Lo scambio dati con ProManage è iniziato a %1.';de = 'Datenaustausch mit ProManage begann am: %1.'"),
		Format(CommonClient.SessionDate(), "DLF=DT"));
			
	Status(MessageText);
			
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ExchangeStartMode", NStr("en = 'Interactive data exchange'; ru = 'Интерактивный обмен данными';pl = 'Interaktywna wymiana danych';es_ES = 'Intercambio de datos interactivo';es_CO = 'Intercambio de datos interactivo';tr = 'İnteraktif veri değişimi';it = 'Scambio dati interattivo';de = 'Interaktiver Datenaustausch'"));
	
	Result = ExchangeCompletedServer(ParametersStructure);
	
	NotifyChanged(Type("DocumentRef.ManufacturingOperation"));
		
	If Not Result.JobCompleted Then
		
		JobID = Result.JobID;
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		IdleHandlerParameters.IntervalIncreaseCoefficient = 1.2;
		AttachIdleHandler("Attachable_CheckJobCompletion", 1, True);
		
	Else
		
		Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1'; ru = '%1';pl = '%1';es_ES = '%1';es_CO = '%1';tr = '%1';it = '%1';de = '%1'"),
				Format(CommonClient.SessionDate(), "DLF=DT"));
		
		ShowUserNotification(Text,
			,
			NStr("en = 'Data exchange with ProManage is completed.'; ru = 'Обмен данными с ProManage завершен.';pl = 'Wymiana danych z ProManage została zakończona.';es_ES = 'Se ha finalizado el intercambio de datos con ProManage.';es_CO = 'Se ha finalizado el intercambio de datos con ProManage.';tr = 'ProManage ile veri değişimi tamamlandı.';it = 'Scambio dati con ProManage completato.';de = 'Datenaustausch mit ProManage ist abgeschlossen.'"),
			PictureLib.Information32);
			
		FillPropertyValues(Items.StatusOfLastExchange, ExchangeWithProManageServerCall.GetStatusOfLastExchange());
		Items.List.Refresh();
			
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishOperationsProManage(Command)
	
	ClearMessages();
	FinishOperationsProManageAtServer();
	
EndProcedure

&AtClient
Procedure StatusOfLastExchange(Command)
	
	Filter = New Structure;
	EventLogEvent = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Data exchange ""%1"". Details: %2.'; ru = 'Обмен данными ""%1"". Подробнее: %2.';pl = 'Wymiana danych ""%1"". Szczegóły: %2.';es_ES = 'Intercambio de datos ""%1"". Detalles: %2.';es_CO = 'Intercambio de datos ""%1"". Detalles: %2.';tr = 'Veri değişimi ""%1"". Ayrıntılar: %2.';it = 'Scambio dati ""%1"". Dettagli: %2.';de = 'Datenaustausch""%1"". Details: %2.'", CommonClientServer.DefaultLanguageCode()),
		ExchangeNode(),
		PredefinedValue("Enum.ActionsOnExchange.DataImport"));
		
	Filter.Insert("EventLogEvent", EventLogEvent);
	OpenForm("DataProcessor.EventLog.Form", Filter);
	
EndProcedure

#EndRegion

#Region Private

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Items.List);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Items.List, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure

// End StandardSubsystems.AttachableCommands

#EndRegion

&AtServer
Procedure FinishOperationsProManageAtServer()
	
	For Each WIP In Items.List.SelectedRows Do
		ExchangeWithProManage.FinishOperationsProManage(WIP);
	EndDo;
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Function ExchangeCompletedServer(Parameters)

	Parameters.Insert("ExchangeNode", ExchangeNode());
	Parameters.Insert("ExchangeStartMode", NStr("en = 'Interactive data exchange'; ru = 'Интерактивный обмен данными';pl = 'Interaktywna wymiana danych';es_ES = 'Intercambio de datos interactivo';es_CO = 'Intercambio de datos interactivo';tr = 'İnteraktif veri değişimi';it = 'Scambio dati interattivo';de = 'Interaktiver Datenaustausch'"));
	JobDescription = NStr("en = 'Sync with ProManage'; ru = 'Синхронизация с ProManage';pl = 'Synchronizuj z ProManage';es_ES = 'Sincronización con ProManage';es_CO = 'Sincronización con ProManage';tr = 'ProManage ile senkronizasyon';it = 'Sincronizzazione con ProManage';de = 'Synchronisieren mit ProManage'");
	
	Result = TimeConsumingOperations.StartBackgroundExecution(
		UUID,
		"ExchangeWithProManage.ExecuteExchange",
		Parameters,
		JobDescription);
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function ExchangeNode()

	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	ProManage.Ref AS Ref
	|FROM
	|	ExchangePlan.Promanage AS ProManage
	|WHERE
	|	NOT ProManage.ThisNode
	|	AND NOT ProManage.DeletionMark";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		ExchangeNode = Selection.Ref;
	EndDo;
	
	Return ExchangeNode;
	
EndFunction

&AtClient
Procedure Attachable_CheckJobCompletion()
	
	If JobCompleted(JobID) Then 
		
		Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 ""%2""'; ru = '%1 ""%2""';pl = '%1 ""%2""';es_ES = '%1 ""%2""';es_CO = '%1 ""%2""';tr = '%1 ""%2""';it = '%1 ""%2""';de = '%1 ""%2""'"),
				Format(CommonClient.SessionDate(), "DLF=DT"),
				Items.List.CurrentRow);
		
		ShowUserNotification(Text,
			,
			NStr("en = 'Data exchange with ProManage is completed.'; ru = 'Обмен данными с ProManage завершен.';pl = 'Wymiana danych z ProManage została zakończona.';es_ES = 'Se ha finalizado el intercambio de datos con ProManage.';es_CO = 'Se ha finalizado el intercambio de datos con ProManage.';tr = 'ProManage ile veri değişimi tamamlandı.';it = 'Scambio dati con ProManage completato.';de = 'Datenaustausch mit ProManage ist abgeschlossen.'"),
			PictureLib.Information32);
			
		FillPropertyValues(Items.StatusOfLastExchange, ExchangeWithProManageServerCall.GetStatusOfLastExchange());
		Items.List.Refresh();
		
	Else
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobCompletion", IdleHandlerParameters.CurrentInterval, True);
	EndIf;

EndProcedure

&AtServerNoContext 
Function JobCompleted(JobID)
	
	Return TimeConsumingOperations.JobCompleted(JobID);
	
EndFunction

#EndRegion