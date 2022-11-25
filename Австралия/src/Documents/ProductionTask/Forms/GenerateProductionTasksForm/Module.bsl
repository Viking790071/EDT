
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillOperationsTable(Parameters.WIPsArray);
	
	SetConditionalAppearance();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ExpandOperationsTable();
	
EndProcedure

#EndRegion

#Region OperationsTableFormTableItemsEventHandlers

&AtClient
Procedure OperationsTableWorkInProgressStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure OperationsTableWorkCenterTypeStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure OperationsTableOperationQuantityOnChange(Item)
	
	CurrentRowID = Items.OperationsTable.CurrentRow;
	CurrentLine = OperationsTable.FindByID(CurrentRowID);
	
	If CurrentLine.OperationQuantity = 0 And ValueIsFilled(CurrentLine.ProductionTask) Then
		
		Mode = QuestionDialogMode.YesNo;
		AddParameters = New Structure("CurrentRowID", CurrentRowID);
		Notification = New NotifyDescription("AfterOperationQuantityQueryClose", ThisObject, AddParameters);
		ShowQueryBox(Notification,
			NStr("en = 'The Production task has already been generated. If you change this quantity to 0 and click ""Generate production tasks"", the generated Production task will be deleted. Do you want to continue?'; ru = 'Производственная задача уже создана. Если изменить это количество на 0 и нажать ""Создать производственные задачи"", созданная производственная задача будет удалена. Продолжить?';pl = 'Zadanie produkcyjne już zostało wygenerowane. Jeśli zmienisz tę ilość na 0 i klikniesz ""Wygeneruj zadania produkcyjne"". wygenerowane Zadania produkcyjne zostanie usunięte. Czy chcesz kontynuować?';es_ES = 'Ya se ha generado la tarea de producción. Si cambia esta cantidad a 0 y pulsa ""Generar tareas de producción"", la tarea de producción generada se borrará. ¿Quiere continuar?';es_CO = 'Ya se ha generado la tarea de producción. Si cambia esta cantidad a 0 y pulsa ""Generar tareas de producción"", la tarea de producción generada se borrará. ¿Quiere continuar?';tr = 'Bu Üretim görevi zaten oluşturuldu. Bu miktarı 0 olarak değiştirip ""Üretim görevleri oluştur"" üzerine tıklarsanız, oluşturulmuş Üretim görevi silinir. Devam etmek istiyor musunuz?';it = 'L''Incarico di produzione è già stato generato. In caso si modifichi la quantità in 0 e si clicchi su ""Generare incarichi di produzione"", l''Incarico di produzione generato sarà cancellato. Continuare?';de = 'Die Produktionsaufgabe wurde bereits generiert. Wenn Sie diese Menge auf 0 ändern und auf „Produktionsaufgaben generieren“ klicken, wird die erstellte Produktionsaufgabe gelöscht. Möchten Sie fortsetzen?'"),
			Mode);
		
	Else
		
		OperationsTableOperationQuantityOnChangeAtClient(CurrentRowID);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OperationsTableStartDatePlannedOnChange(Item)
	
	CurrentLine = OperationsTable.FindByID(Items.OperationsTable.CurrentRow);
	CurrentLine.StartDateWasChanged = True;
	
	CheckCorrectDate(CurrentLine, "StartDatePlanned");
	
EndProcedure

&AtClient
Procedure OperationsTableEndDatePlannedOnChange(Item)
	
	CurrentLine = OperationsTable.FindByID(Items.OperationsTable.CurrentRow);
	CurrentLine.EndDateWasChanged = True;
	
	CheckCorrectDate(CurrentLine, "EndDatePlanned");
	
EndProcedure

&AtClient
Procedure OperationsTableProductionTaskStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ExpandAll(Command)
	
	ExpandOperationsTable();
	
EndProcedure

&AtClient
Procedure CollapseAll(Command)
	
	CollapseRecursively(OperationsTable.GetItems());
	
EndProcedure

&AtClient
Procedure GenerateProductionTasks(Command)
	
	If CheckNegativeValues() Then
		
		TasksGenerated = GenerateProductionTasksAtServer();
		
		If TasksGenerated.Created > 0 Then
			ShowUserNotification(
				StringFunctionsClientServer.SubstituteParametersToString(
					?(TasksGenerated.Created = 1,
						NStr("en = '%1 task was generated.'; ru = 'Задача %1 создана.';pl = 'Zadanie %1 zostało wygenerowane.';es_ES = 'Se ha generado la tarea %1.';es_CO = 'Se ha generado la tarea %1.';tr = '%1 görev oluşturuldu.';it = '%1 incarico generato.';de = 'Aufgabe %1 wurde generiert.'"),
						NStr("en = '%1 tasks were generated.'; ru = 'Создано %1 задач.';pl = 'Zadania %1 zostały wygenerowane.';es_ES = 'Se han generado las tareas %1.';es_CO = 'Se han generado las tareas %1.';tr = '%1 görev oluşturuldu.';it = '%1 incarichi generati.';de = 'Aufgaben %1 wurden generiert.'")),
					TasksGenerated.Created));
		EndIf;
		
		If TasksGenerated.Changed > 0 Then
			ShowUserNotification(
				StringFunctionsClientServer.SubstituteParametersToString(
					?(TasksGenerated.Changed = 1,
						NStr("en = '%1 task was changed.'; ru = 'Изменена %1 задача.';pl = 'Zadanie %1 zostało zmienione.';es_ES = 'La tarea %1 se ha cambiado.';es_CO = 'La tarea %1 se ha cambiado.';tr = '%1 görev değiştirildi.';it = '%1 incarico modificato.';de = 'Aufgabe %1 ist geändert.'"),
						NStr("en = '%1 tasks were changed.'; ru = 'Изменено %1 задач.';pl = 'Zadania %1 zostały zmienione.';es_ES = 'La tareas %1 se han cambiado.';es_CO = 'La tareas %1 se han cambiado.';tr = '%1 görev değiştirildi.';it = '%1 incarichi modificati.';de = 'Aufgaben %1 sind geändert.'")),
					TasksGenerated.Changed));
		EndIf;
		
		If TasksGenerated.Deleted > 0 Then
			ShowUserNotification(
				StringFunctionsClientServer.SubstituteParametersToString(
					?(TasksGenerated.Deleted = 1,
						NStr("en = '%1 task was deleted.'; ru = 'Удалена %1 задача.';pl = 'Zadanie %1 zostało usunięte.';es_ES = 'La tarea %1 ha sido eliminada.';es_CO = 'La tarea %1 ha sido eliminada.';tr = '%1 görev değiştirildi.';it = '%1 incarico cancellato.';de = 'Aufgabe %1 ist gelöscht.'"),
						NStr("en = '%1 tasks were deleted.'; ru = 'Удалено %1 задач.';pl = 'Zadania %1 zostały usunięte.';es_ES = 'La tareas %1 se han eliminado.';es_CO = 'La tareas %1 se han eliminado.';tr = '%1 görev silindi.';it = '%1 incarichi cancellati.';de = 'Aufgaben %1 sind gelöscht.'")),
					TasksGenerated.Deleted));
		EndIf;
		
		Notify("ProductionTaskStatuseChanged");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillOperationFromSchedule(Command)
	
	CurrentLine = OperationsTable.FindByID(Items.OperationsTable.CurrentRow);
	
	RefillLevelFromSchedule(CurrentLine, CurrentLine.LineType);
	
EndProcedure

&AtClient
Procedure FillFromSchedule(Command)
	
	LevelWorkInProgress = OperationsTable.GetItems();
	For Each LevelWorkInProgress_Item In LevelWorkInProgress Do
		
		RefillLevelFromSchedule(LevelWorkInProgress_Item, LevelWorkInProgress_Item.LineType);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterOperationQuantityQueryClose(Result, AddParameters) Export
	
	CurrentRowID = AddParameters.CurrentRowID;
	
	If Result = DialogReturnCode.Yes Then
		
		OperationsTableOperationQuantityOnChangeAtClient(CurrentRowID);
		
	Else
		
		CurrentLine = OperationsTable.FindByID(CurrentRowID);
		CurrentLine.OperationQuantity = CurrentLine.OperationQuantityBeforeChange;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OperationsTableOperationQuantityOnChangeAtClient(CurrentRowID)
	
	CurrentLine = OperationsTable.FindByID(CurrentRowID);
	CurrentLine.OperationQuantityBeforeChange = CurrentLine.OperationQuantity;
	CurrentLine.QuantityWasChanged = True;
	
	Parent = CurrentLine.GetParent();
	If Parent <> Undefined Then
		
		CalculateTotalsInLine(Parent);
		Delta = Parent.QuantityLeft;
		
		// Try to balance by empty work center
		If Delta <> 0 And ValueIsFilled(CurrentLine.WorkCenterTypeWorkCenter) Then
			
			TreeItems = Parent.GetItems();
			For Each TreeItems_Item In TreeItems Do
				
				If Not ValueIsFilled(TreeItems_Item.WorkCenterTypeWorkCenter) Then
					
					If Delta > 0 Then
						TreeItems_Item.OperationQuantity = TreeItems_Item.OperationQuantity + Delta;
						TreeItems_Item.OperationQuantityBeforeChange = TreeItems_Item.OperationQuantity;
						TreeItems_Item.QuantityWasChanged = True;
						CalculateTotalsInLine(Parent);
					ElsIf Delta < 0 And TreeItems_Item.OperationQuantity >= (-Delta) Then
						TreeItems_Item.OperationQuantity = TreeItems_Item.OperationQuantity + Delta;
						TreeItems_Item.OperationQuantityBeforeChange = TreeItems_Item.OperationQuantity;
						TreeItems_Item.QuantityWasChanged = True;
						CalculateTotalsInLine(Parent);
					EndIf;
					
					Break;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillOperationsTable(WIPsArray)
	
	Tree = FormAttributeToValue("OperationsTable");
	
	Tree.Rows.Clear();
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ManufacturingOperationActivities.Activity AS Activity,
	|	ManufacturingOperationActivities.Quantity AS Quantity,
	|	ManufacturingOperationActivities.StandardTime AS StandardTime,
	|	ManufacturingOperationActivities.Ref AS WorkInProgress,
	|	ProductionOrder.UseProductionPlanning AS UseProductionPlanning,
	|	ManufacturingOperationActivities.ConnectionKey AS ConnectionKey
	|INTO TT_WIPs
	|FROM
	|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		LEFT JOIN Document.ManufacturingOperation AS ManufacturingOperation
	|		ON ManufacturingOperationActivities.Ref = ManufacturingOperation.Ref
	|		LEFT JOIN Document.ProductionOrder AS ProductionOrder
	|		ON (ManufacturingOperation.BasisDocument = ProductionOrder.Ref)
	|WHERE
	|	ManufacturingOperationActivities.Ref IN(&WIPs)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkcentersSchedule.WorkcenterType AS WorkcenterType,
	|	WorkcentersSchedule.Operation AS Operation,
	|	MIN(WorkcentersSchedule.StartDate) AS StartDate,
	|	SUM(WorkcentersSchedule.WorkloadTime) AS WorkloadTime,
	|	MAX(WorkcentersSchedule.EndDate) AS EndDate,
	|	SUM(WorkcentersSchedule.Quantity) AS Quantity,
	|	WorkcentersSchedule.Workcenter AS Workcenter,
	|	TT_WIPs.Activity AS Activity,
	|	CompanyResourceTypes.PlanningOnWorkcentersLevel AS PlanningOnWorkcentersLevel,
	|	WorkcentersSchedule.ConnectionKey AS ConnectionKey
	|INTO TT_PlannedWithWCT
	|FROM
	|	InformationRegister.WorkcentersSchedule AS WorkcentersSchedule
	|		INNER JOIN TT_WIPs AS TT_WIPs
	|		ON WorkcentersSchedule.Operation = TT_WIPs.WorkInProgress
	|			AND WorkcentersSchedule.ConnectionKey = TT_WIPs.ConnectionKey
	|		LEFT JOIN Catalog.CompanyResourceTypes AS CompanyResourceTypes
	|		ON WorkcentersSchedule.WorkcenterType = CompanyResourceTypes.Ref
	|
	|GROUP BY
	|	WorkcentersSchedule.Operation,
	|	WorkcentersSchedule.WorkcenterType,
	|	WorkcentersSchedule.Workcenter,
	|	TT_WIPs.Activity,
	|	CompanyResourceTypes.PlanningOnWorkcentersLevel,
	|	WorkcentersSchedule.ConnectionKey
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionSchedule.Operation AS Operation,
	|	ProductionSchedule.StartDate AS StartDate,
	|	ProductionSchedule.EndDate AS EndDate,
	|	SUM(TT_WIPs.Quantity) AS Quantity,
	|	TT_WIPs.Activity AS Activity,
	|	ProductionSchedule.ConnectionKey AS ConnectionKey
	|INTO TT_PlannedWithoutWCT
	|FROM
	|	InformationRegister.ProductionSchedule AS ProductionSchedule
	|		INNER JOIN TT_WIPs AS TT_WIPs
	|		ON ProductionSchedule.Operation = TT_WIPs.WorkInProgress
	|			AND ProductionSchedule.ConnectionKey = TT_WIPs.ConnectionKey
	|		LEFT JOIN TT_PlannedWithWCT AS TT_PlannedWithWCT
	|		ON ProductionSchedule.Activity = TT_PlannedWithWCT.Activity
	|WHERE
	|	ProductionSchedule.ScheduleState = 0
	|	AND TT_PlannedWithWCT.Operation IS NULL
	|
	|GROUP BY
	|	ProductionSchedule.Operation,
	|	ProductionSchedule.StartDate,
	|	ProductionSchedule.EndDate,
	|	TT_WIPs.Activity,
	|	ProductionSchedule.ConnectionKey
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_WIPs.WorkInProgress AS WorkInProgress,
	|	TT_WIPs.Activity AS Activity,
	|	TT_WIPs.Quantity AS Quantity,
	|	ManufacturingActivitiesWorkCenterTypes.WorkcenterType AS WorkcenterType,
	|	TT_WIPs.UseProductionPlanning AS UseProductionPlanning,
	|	TT_WIPs.ConnectionKey AS ConnectionKey
	|INTO TT_NotPlannedWIPs
	|FROM
	|	TT_WIPs AS TT_WIPs
	|		LEFT JOIN Catalog.ManufacturingActivities.WorkCenterTypes AS ManufacturingActivitiesWorkCenterTypes
	|		ON TT_WIPs.Activity = ManufacturingActivitiesWorkCenterTypes.Ref
	|WHERE
	|	NOT TT_WIPs.WorkInProgress IN
	|				(SELECT
	|					TT_PlannedWithWCT.Operation AS Operation
	|				FROM
	|					TT_PlannedWithWCT AS TT_PlannedWithWCT
	|		
	|				UNION ALL
	|		
	|				SELECT
	|					TT_PlannedWithoutWCT.Operation
	|				FROM
	|					TT_PlannedWithoutWCT AS TT_PlannedWithoutWCT)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionAccomplishmentTurnovers.WorkInProgress AS WorkInProgress,
	|	ProductionAccomplishmentTurnovers.QuantityReceipt AS TasksQuantity,
	|	ProductionAccomplishmentTurnovers.QuantityExpense AS WIPQuantity,
	|	ProductionAccomplishmentTurnovers.Operation AS Operation
	|INTO TT_ProductionAccomplishment
	|FROM
	|	AccumulationRegister.ProductionAccomplishment.Turnovers(, , Period, WorkInProgress IN (&WIPs)) AS ProductionAccomplishmentTurnovers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_PlannedWithWCT.Operation AS WorkInProgress,
	|	TT_PlannedWithWCT.Activity AS Operation,
	|	TT_PlannedWithWCT.Quantity AS OperationQuantity,
	|	TT_PlannedWithWCT.WorkcenterType AS WorkCenterType,
	|	TT_PlannedWithWCT.Workcenter AS WorkCenter,
	|	TT_PlannedWithWCT.StartDate AS StartDatePlanned,
	|	TT_PlannedWithWCT.EndDate AS EndDatePlanned,
	|	ISNULL(TT_ProductionAccomplishment.TasksQuantity, 0) AS TasksQuantity,
	|	ISNULL(TT_ProductionAccomplishment.WIPQuantity, 0) AS WIPQuantity,
	|	CASE
	|		WHEN TT_PlannedWithWCT.PlanningOnWorkcentersLevel
	|			THEN &DecriptionPlannedWithWC
	|		ELSE &DecriptionPlannedWithoutWC
	|	END AS PlanningInfo,
	|	TT_PlannedWithWCT.ConnectionKey AS ConnectionKey
	|FROM
	|	TT_PlannedWithWCT AS TT_PlannedWithWCT
	|		LEFT JOIN TT_ProductionAccomplishment AS TT_ProductionAccomplishment
	|		ON TT_PlannedWithWCT.Operation = TT_ProductionAccomplishment.WorkInProgress
	|			AND TT_PlannedWithWCT.Activity = TT_ProductionAccomplishment.Operation
	|
	|UNION ALL
	|
	|SELECT
	|	TT_PlannedWithoutWCT.Operation,
	|	TT_PlannedWithoutWCT.Activity,
	|	TT_PlannedWithoutWCT.Quantity,
	|	VALUE(Catalog.CompanyResourceTypes.EmptyRef),
	|	VALUE(Catalog.CompanyResources.EmptyRef),
	|	TT_PlannedWithoutWCT.StartDate,
	|	TT_PlannedWithoutWCT.EndDate,
	|	ISNULL(TT_ProductionAccomplishment.TasksQuantity, 0),
	|	ISNULL(TT_ProductionAccomplishment.WIPQuantity, 0),
	|	&DescriptionPlannedNoWCT,
	|	TT_PlannedWithoutWCT.ConnectionKey
	|FROM
	|	TT_PlannedWithoutWCT AS TT_PlannedWithoutWCT
	|		LEFT JOIN TT_ProductionAccomplishment AS TT_ProductionAccomplishment
	|		ON TT_PlannedWithoutWCT.Operation = TT_ProductionAccomplishment.WorkInProgress
	|			AND TT_PlannedWithoutWCT.Activity = TT_ProductionAccomplishment.Operation
	|
	|UNION ALL
	|
	|SELECT
	|	TT_NotPlannedWIPs.WorkInProgress,
	|	TT_NotPlannedWIPs.Activity,
	|	TT_NotPlannedWIPs.Quantity,
	|	TT_NotPlannedWIPs.WorkcenterType,
	|	VALUE(Catalog.CompanyResources.EmptyRef),
	|	NULL,
	|	NULL,
	|	ISNULL(TT_ProductionAccomplishment.TasksQuantity, 0),
	|	ISNULL(TT_ProductionAccomplishment.WIPQuantity, 0),
	|	CASE
	|		WHEN TT_NotPlannedWIPs.UseProductionPlanning
	|			THEN &DescriptionNotPlanned
	|		ELSE &DescriptionNoPlanning
	|	END,
	|	TT_NotPlannedWIPs.ConnectionKey
	|FROM
	|	TT_NotPlannedWIPs AS TT_NotPlannedWIPs
	|		LEFT JOIN TT_ProductionAccomplishment AS TT_ProductionAccomplishment
	|		ON TT_NotPlannedWIPs.WorkInProgress = TT_ProductionAccomplishment.WorkInProgress
	|			AND TT_NotPlannedWIPs.Activity = TT_ProductionAccomplishment.Operation
	|
	|ORDER BY
	|	StartDatePlanned,
	|	WorkInProgress
	|TOTALS
	|	MAX(Operation),
	|	SUM(OperationQuantity),
	|	MAX(WorkCenterType),
	|	MAX(TasksQuantity),
	|	MAX(WIPQuantity),
	|	MAX(PlanningInfo)
	|BY
	|	WorkInProgress,
	|	ConnectionKey";
	
	Query.SetParameter("WIPs", WIPsArray);
	Query.SetParameter("DescriptionNotPlanned", NStr("en = 'Included in production planning but not scheduled yet'; ru = 'Включено в планирование производства, но еще не запланировано';pl = 'Zawarte w planowaniu produkcji ale jeszcze nie zaplanowane';es_ES = 'Está incluido en la planificación de la producción, pero aún no está programado';es_CO = 'Está incluido en la planificación de la producción, pero aún no está programado';tr = 'Üretim planlamasına dahil fakat henüz programa eklenmedi';it = 'Incluso nella pianificazione di produzione ma non ancora programmato';de = 'In der Produktionsplanung enthalten, aber noch nicht geplant'"));
	Query.SetParameter("DescriptionNoPlanning", NStr("en = 'Not included in production planning'; ru = 'Не включено в планирование производства';pl = 'Nieuwzględnione w planowaniu produkcji';es_ES = 'No se incluye en la planificación de la producción';es_CO = 'No se incluye en la planificación de la producción';tr = 'Üretim planlamasına dahil değil';it = 'Non incluso nella pianificazione di produzione';de = 'In Produktionsplanung nicht eingeschlossen'"));
	Query.SetParameter("DescriptionPlannedNoWCT", NStr("en = 'Planned without work center and work center type'; ru = 'Запланировано без рабочего центра и типа рабочего центра';pl = 'Zaplanowane bez gniazda produkcyjnego i typu gniazda produkcyjnego';es_ES = 'Planificación sin centro de trabajo y tipo de centro de trabajo';es_CO = 'Planificación sin centro de trabajo y tipo de centro de trabajo';tr = 'İş merkezi ve İş merkezi türü olmadan planlandı';it = 'Pianificato senza centro di lavoro e tipo di centro di lavoro';de = 'Ohne Arbeitsabschnitt und Arbeitsabschnittstyp geplant'"));
	Query.SetParameter("DecriptionPlannedWithWC", NStr("en = 'Planned on work center level'; ru = 'Запланировано на уровне рабочего центра';pl = 'Zaplanowane na poziomie gniazda produkcyjnego';es_ES = 'Planificación a nivel del centro de trabajo';es_CO = 'Planificación a nivel del centro de trabajo';tr = 'İş merkezi seviyesinde planlandı';it = 'Pianificato a livello di centro di lavoro';de = 'Auf der Ebene des Arbeitsabschnitts geplant'"));
	Query.SetParameter("DecriptionPlannedWithoutWC", NStr("en = 'Planned on work center type level'; ru = 'Запланировано на уровне типа рабочего центра';pl = 'Zaplanowane na poziomie typu gniazda produkcyjnego';es_ES = 'Planificación a nivel de tipo de centro de trabajo';es_CO = 'Planificación a nivel de tipo de centro de trabajo';tr = 'İş merkezi türü seviyesinde planlandı';it = 'Pianificato a livello di tipo di centro di lavoro';de = 'Auf der Ebene des Arbeitsabschnittstyps geplant'"));
	
	QueryResult = Query.Execute();
	
	SelectionWorkInProgress = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While SelectionWorkInProgress.Next() Do
		
		WIPLine = Tree.Rows.Add();
		WIPLine.WorkInProgressOperation = SelectionWorkInProgress.WorkInProgress;
		WIPLine.LineType = 0;
		
		SelectionOperation = SelectionWorkInProgress.Select(QueryResultIteration.ByGroups);
	
		While SelectionOperation.Next() Do
			
			OperationLine = WIPLine.Rows.Add();
			OperationLine.WorkInProgressOperation = SelectionOperation.Operation;
			OperationLine.ConnectionKey = SelectionOperation.ConnectionKey;
			OperationLine.WIPQuantity = SelectionOperation.WIPQuantity;
			OperationLine.OperationQuantity = ?(SelectionOperation.TasksQuantity > 0, 0, SelectionOperation.OperationQuantity);
			OperationLine.OperationQuantityBeforeChange = OperationLine.OperationQuantity;
			OperationLine.TasksQuantity = SelectionOperation.TasksQuantity;
			OperationLine.QuantityLeft = OperationLine.WIPQuantity
				- OperationLine.OperationQuantity
				- OperationLine.TasksQuantity;
			OperationLine.WorkCenterTypeWorkCenter = SelectionOperation.WorkCenterType;
			OperationLine.LineType = 1;
			OperationLine.PlanningInfo = SelectionOperation.PlanningInfo;
			
			SelectionDetailRecords = SelectionOperation.Select();
			
			AddWCLines(OperationLine.Rows, SelectionDetailRecords, SelectionOperation.WorkCenterType, OperationLine.TasksQuantity > 0);
			
		EndDo;
		
	EndDo;
	
	ValueToFormAttribute(Tree, "OperationsTable");
	
EndProcedure

&AtServer
Procedure AddWCLines(WorkCenterTypeRows, SelectionDetailRecords, WorkCenterType, HasTasks)
	
	WorkCenterLine = WorkCenterTypeRows.Add();
	WorkCenterLine.WorkCenterTypeWorkCenter =
		?(ValueIsFilled(WorkCenterType), Catalogs.CompanyResources.EmptyRef(), Undefined);
	WorkCenterLine.LineType = 2;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CompanyResources.Ref AS Ref
	|FROM
	|	Catalog.CompanyResources AS CompanyResources
	|WHERE
	|	CompanyResources.WorkcenterType = &WorkcenterType
	|	AND NOT CompanyResources.DeletionMark";
	
	Query.SetParameter("WorkcenterType", WorkCenterType);
	
	QueryResult = Query.Execute();
	
	SelectionCompanyResources = QueryResult.Select();
	
	While SelectionCompanyResources.Next() Do
		WorkCenterLine = WorkCenterTypeRows.Add();
		WorkCenterLine.WorkCenterTypeWorkCenter = SelectionCompanyResources.Ref;
		WorkCenterLine.LineType = 2;
	EndDo;
	
	While SelectionDetailRecords.Next() Do
		
		WorkCenter = SelectionDetailRecords.WorkCenter;
		If Not ValueIsFilled(WorkCenter) Then
			
			WorkCenter = ?(ValueIsFilled(WorkCenterType), Catalogs.CompanyResources.EmptyRef(), Undefined);
			
		EndIf;
		
		ParametersFilter = New Structure;
		ParametersFilter.Insert("WorkCenterTypeWorkCenter", WorkCenter);
		FoundLines = WorkCenterTypeRows.FindRows(ParametersFilter);
		
		If FoundLines.Count() Then
			
			WorkCenterLine = FoundLines[0];
			
			If Not HasTasks Then
				WorkCenterLine.StartDatePlanned = SelectionDetailRecords.StartDatePlanned;
				WorkCenterLine.EndDatePlanned = SelectionDetailRecords.EndDatePlanned;
				WorkCenterLine.OperationQuantity = WorkCenterLine.OperationQuantity + SelectionDetailRecords.OperationQuantity;
				WorkCenterLine.OperationQuantityBeforeChange = WorkCenterLine.OperationQuantity;
			EndIf;
			
			WorkCenterLine.QuantityFromSchedule = WorkCenterLine.QuantityFromSchedule + SelectionDetailRecords.OperationQuantity;
			WorkCenterLine.StartDateFromSchedule = SelectionDetailRecords.StartDatePlanned;
			WorkCenterLine.EndDateFromSchedule = SelectionDetailRecords.EndDatePlanned;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	// Work Center type - italics
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OperationsTable.LineType",
		0,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsTableOperationQuantity");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Show", False);
	
	// Quantity left < 0 - red
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OperationsTable.QuantityLeft",
		0,
		DataCompositionComparisonType.Less);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsTableQuantityLeft");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", WebColors.DarkRed);
	
	// Work Center - read only
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OperationsTable.LineType",
		2,
		DataCompositionComparisonType.NotEqual);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"OperationsTableOperationQuantity,
		|OperationsTableStartDatePlanned,
		|OperationsTableEndDatePlanned");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// Work Center type - italics
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OperationsTable.LineType",
		2,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsTableWorkCenterType");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Font", New Font(,,, True));
	
	// Work Center - <any work center>
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OperationsTable.LineType",
		2,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OperationsTable.WorkCenterTypeWorkCenter",
		Catalogs.CompanyResources.EmptyRef(),
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsTableWorkCenterType");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", NStr("en = '<any work center>'; ru = '<любой рабочий центр>';pl = '<dowolne gniazdo produkcyjne>';es_ES = '<cualquier centro de trabajo>';es_CO = '<cualquier centro de trabajo>';tr = '<herhangi bir iş merkezi>';it = '<qualsiasi centro di lavoro>';de = '<jeder Arbeitsabschnitt>'"));
	
	// Work Center - <without work center>
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OperationsTable.LineType",
		2,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OperationsTable.WorkCenterTypeWorkCenter",
		Undefined,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsTableWorkCenterType");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", NStr("en = '<without work center>'; ru = '<без рабочего центра>';pl = '<bez gniazda produkcyjnego>';es_ES = '<sin centro de trabajo>';es_CO = '<sin centro de trabajo>';tr = '<iş merkezi olmadan>';it = '<senza centro di lavoro>';de = '<ohne Arbeitsabschnitt>'"));
	
	// Work Center - <without work center type>
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OperationsTable.LineType",
		1,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OperationsTable.WorkCenterTypeWorkCenter",
		Catalogs.CompanyResourceTypes.EmptyRef(),
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsTableWorkCenterType");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", NStr("en = '<without work center type>'; ru = '<без типа рабочего центра>';pl = '<bez typu gniazda produkcyjnego>';es_ES = '<sin tipo de centro de trabajo>';es_CO = '<sin tipo de centro de trabajo>';tr = '<iş merkezi türü olmadan>';it = '<senza tipo di centro di lavoro>';de = '<ohne Arbeitsabschnittstyp>'"));
	
	// Work Center - changed data in bold
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OperationsTable.QuantityWasChanged",
		True,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsTableOperationQuantity");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Font", New Font(,,True));
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OperationsTable.StartDateWasChanged",
		True,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsTableStartDatePlanned");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Font", New Font(,,True));
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OperationsTable.EndDateWasChanged",
		True,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsTableEndDatePlanned");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Font", New Font(,,True));
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OperationsTable.LineType",
		1,
		DataCompositionComparisonType.NotEqual);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OperationsTablePlanningInfo");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Visible", False);
	
EndProcedure

&AtClient
Procedure ExpandOperationsTable()
	
	LevelProducts = OperationsTable.GetItems();
	For Each LevelProducts_Item In LevelProducts Do
		Items.OperationsTable.Expand(LevelProducts_Item.GetID(), True);
	EndDo;
	
EndProcedure

&AtClient
Procedure CollapseRecursively(TreeItems)
	
	For Each TreeItems_Item In TreeItems Do
		
		InTreeItems = TreeItems_Item.GetItems();
		If InTreeItems.Count() > 0 Then
			CollapseRecursively(InTreeItems);
		EndIf;
		Items.OperationsTable.Collapse(TreeItems_Item.GetID());
		
	EndDo;
	
EndProcedure

&AtClient
Procedure CalculateTotalsInLine(Parent)
	
	TreeItems = Parent.GetItems();
	OperationQuantity = 0;
	
	For Each TreeItems_Item In TreeItems Do
		
		OperationQuantity = OperationQuantity + TreeItems_Item.OperationQuantity;
		
	EndDo;
	
	Parent.OperationQuantity = OperationQuantity;
	Parent.QuantityLeft = Parent.WIPQuantity
		- Parent.OperationQuantity
		- Parent.TasksQuantity;
	
EndProcedure

&AtServer
Function GenerateProductionTasksAtServer()
	
	CounterCreated = 0;
	CounterChanged = 0;
	CounterDeleted = 0;
	
	LevelWorkInProgress = OperationsTable.GetItems();
	For Each LevelWorkInProgress_Item In LevelWorkInProgress Do
		
		WorkInProgress = LevelWorkInProgress_Item.WorkInProgressOperation;
		
		LevelOperation = LevelWorkInProgress_Item.GetItems();
		For Each LevelOperation_Item In LevelOperation Do
			
			Operation = LevelOperation_Item.WorkInProgressOperation;
			ConnectionKey = LevelOperation_Item.ConnectionKey;
			WorkcenterType = LevelOperation_Item.WorkCenterTypeWorkCenter;
			
			LevelWCQuantity = 0;
			LevelWC = LevelOperation_Item.GetItems();
			For Each LevelWC_Item In LevelWC Do
				
				If Not ValueIsFilled(LevelWC_Item.ProductionTask) And LevelWC_Item.OperationQuantity > 0 Then
					
					ProductionTask = GenerateProductionTask(WorkInProgress, Operation, ConnectionKey, WorkcenterType, LevelWC_Item);
					LevelWC_Item.ProductionTask = ProductionTask;
					
					CounterCreated = CounterCreated + 1;
					
				ElsIf ValueIsFilled(LevelWC_Item.ProductionTask) Then
					
					If LevelWC_Item.QuantityWasChanged
						Or LevelWC_Item.EndDateWasChanged
						Or LevelWC_Item.StartDateWasChanged Then
						
						If LevelWC_Item.OperationQuantity = 0 Then
							
							DeleteProductionTask(LevelWC_Item);
							
							CounterDeleted = CounterDeleted + 1;
							LevelWC_Item.ProductionTask = Documents.ProductionTask.EmptyRef();
							
						Else
							
							ChangeProductionTask(LevelWC_Item);
							CounterChanged = CounterChanged + 1;
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
				LevelWC_Item.QuantityWasChanged = False;
				LevelWC_Item.StartDateWasChanged = False;
				LevelWC_Item.EndDateWasChanged = False;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
	ReturnStructure = New Structure("Created, Changed, Deleted", CounterCreated, CounterChanged, CounterDeleted);
	
	Return ReturnStructure;
	
EndFunction

&AtServer
Function GenerateProductionTask(WorkInProgress, Operation, ConnectionKey, WorkcenterType, WCLine)
	
	ProductionTask = Documents.ProductionTask.CreateDocument();
	
	ProductionTask.FillByWorkInProgress(WorkInProgress, ConnectionKey);
	ProductionTask.Date = CurrentSessionDate();
	ProductionTask.Author = Users.CurrentUser();
	ProductionTask.Status = Enums.ProductionTaskStatuses.Open;
	
	If ProductionTask.Operation <> Operation Or ProductionTask.OperationQuantity <> WCLine.OperationQuantity Then
		
		// Change inventory quantity
		If ProductionTask.Operation = Operation Then
			
			For Each InventoryLine In ProductionTask.Inventory Do
				
				If ProductionTask.OperationQuantity <> 0 Then
					InventoryLine.Quantity = (InventoryLine.Quantity / ProductionTask.OperationQuantity) * WCLine.OperationQuantity;
				EndIf;
				
			EndDo;
			
		Else
			
			ProductionTask.Inventory.Clear();
			
		EndIf;
		
		ProductionTask.Operation = Operation;
		ProductionTask.ConnectionKey = ConnectionKey;
		ProductionTask.OperationQuantity = WCLine.OperationQuantity;
		
	EndIf;
	
	ProductionTask.StartDatePlanned = WCLine.StartDatePlanned;
	ProductionTask.EndDatePlanned = WCLine.EndDatePlanned;
	ProductionTask.WorkcenterType = WorkcenterType;
	ProductionTask.Workcenter = WCLine.WorkCenterTypeWorkCenter;
	
	Try
		ProductionTask.Write(DocumentWriteMode.Posting);
	Except
		ProductionTask.Write(DocumentWriteMode.Write);
	EndTry;
	
	Return ProductionTask.Ref;
	
EndFunction

&AtServer
Procedure ChangeProductionTask(WCLine)
	
	ProductionTask = WCLine.ProductionTask.GetObject();
	
	If ProductionTask.OperationQuantity <> WCLine.OperationQuantity Then
		
		For Each InventoryLine In ProductionTask.Inventory Do
			
			If ProductionTask.OperationQuantity <> 0 Then
				InventoryLine.Quantity = (InventoryLine.Quantity / ProductionTask.OperationQuantity) * WCLine.OperationQuantity;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	ProductionTask.OperationQuantity = WCLine.OperationQuantity;
	ProductionTask.StartDatePlanned = WCLine.StartDatePlanned;
	ProductionTask.EndDatePlanned = WCLine.EndDatePlanned;
	
	Try
		ProductionTask.Write(DocumentWriteMode.Posting);
	Except
		ProductionTask.Write(DocumentWriteMode.Write);
	EndTry;
	
EndProcedure

&AtServer
Procedure DeleteProductionTask(WCLine)
	
	ProductionTask = WCLine.ProductionTask.GetObject();
	ProductionTask.SetDeletionMark(True);
	
EndProcedure

&AtClient
Procedure RefillLevelFromSchedule(TableLine, LineType)
	
	// WIP level
	If LineType = 0 Then
		
		LevelOperation = TableLine.GetItems();
		For Each LevelOperation_Item In LevelOperation Do
			
			LevelWC = LevelOperation_Item.GetItems();
			For Each LevelWC_Item In LevelWC Do
				
				RefillLineFromSchedule(LevelWC_Item);
				
			EndDo;
			
			CalculateTotalsInLine(LevelOperation_Item);
			
		EndDo;
		
	// Operation level
	ElsIf LineType = 1 Then
		
		LevelWC = TableLine.GetItems();
		For Each LevelWC_Item In LevelWC Do
			
			RefillLineFromSchedule(LevelWC_Item);
			
		EndDo;
		CalculateTotalsInLine(TableLine);
		
	// WC level
	Else
		
		RefillLineFromSchedule(TableLine);
		CalculateTotalsInLine(TableLine.GetParent());
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefillLineFromSchedule(LevelWC_Item)
	
	LevelWC_Item.OperationQuantity = LevelWC_Item.QuantityFromSchedule;
	LevelWC_Item.OperationQuantityBeforeChange = LevelWC_Item.OperationQuantity;
	LevelWC_Item.StartDatePlanned = LevelWC_Item.StartDateFromSchedule;
	LevelWC_Item.EndDatePlanned = LevelWC_Item.EndDateFromSchedule;
	
	LevelWC_Item.QuantityWasChanged = False;
	LevelWC_Item.StartDateWasChanged = False;
	LevelWC_Item.EndDateWasChanged = False;
	
EndProcedure

&AtClient
Function CheckNegativeValues()
	
	Result = True;
	
	LevelWorkInProgress = OperationsTable.GetItems();
	For Each LevelWorkInProgress_Item In LevelWorkInProgress Do
		
		WorkInProgress = LevelWorkInProgress_Item.WorkInProgressOperation;
		
		LevelOperation = LevelWorkInProgress_Item.GetItems();
		For Each LevelOperation_Item In LevelOperation Do
			
			If LevelOperation_Item.QuantityLeft < 0 Then
				
				Result = False;
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Operation %2 requires not more than %1 Production tasks. Edit the quanity of Production tasks and try again.'; ru = 'Операция %2 требует не более %1 производственных задач. Измените количество производственных задач и повторите попытку.';pl = 'Operacja %2 wymaga nie więcej niż %1 Zadań produkcyjnych. Edytuj ilość Zadań produkcyjnych i spróbuj ponownie.';es_ES = 'La operación %2 no requiere más de %1 tareas de producción. Edite la cantidad de tareas de producción e inténtelo de nuevo.';es_CO = 'La operación %2 no requiere más de %1 tareas de producción. Edite la cantidad de tareas de producción e inténtelo de nuevo.';tr = '%2 operasyonu %1 üretim görevinden daha fazlasını gerektiriyor. Üretim görevi adedini değiştirip tekrar deneyin.';it = 'L''operazione %2 richiede non più di %1 Incarichi di produzione. Modificare la quantità di Incarichi di lavoro e riprovare.';de = 'Operation %2 erfordert nicht mehr als %1 Produktionsaufgaben. Bearbeiten Sie die Menge der Produktionsaufgaben, und versuchen Sie es erneut.'"),
					LevelOperation_Item.WIPQuantity - LevelOperation_Item.TasksQuantity,
					LevelOperation_Item.WorkInProgressOperation);
				CommonClientServer.MessageToUser(ErrorText);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure CheckCorrectDate(CurrentLine, ItemName)
	
	If ValueIsFilled(CurrentLine.StartDatePlanned) And ValueIsFilled(CurrentLine.EndDatePlanned)
		And CurrentLine.StartDatePlanned > CurrentLine.EndDatePlanned Then
		
		CurrentLine[ItemName] = Date(1,1,1);
		ErrorText = NStr("en = 'The scheduled start date cannot be later than the scheduled due date.'; ru = 'Плановая дата начала не может быть больше плановой даты завершения.';pl = 'Zaplanowana data rozpoczęcia nie może być późniejsza niż zaplanowany termin.';es_ES = 'La fecha de inicio programada no puede ser posterior a la fecha de vencimiento programada.';es_CO = 'La fecha de inicio programada no puede ser posterior a la fecha de vencimiento programada.';tr = 'Programlı başlangıç tarihi programlı bitiş tarihinden sonra olamaz.';it = 'La data di inizio pianificata non può essere successiva alla data di scadenza pianificata.';de = 'Das geplante Startdatum darf nicht nach dem geplanten Fälligkeitstermin liegen.'");
		CommonClientServer.MessageToUser(ErrorText);

	EndIf;
		
EndProcedure

#EndRegion