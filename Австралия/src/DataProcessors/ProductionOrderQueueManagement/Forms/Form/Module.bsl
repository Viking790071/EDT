#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FilterStartDateOnChange(Undefined);
	FilterPriorityOnChange(Undefined);
	FilterDepartmentOnChange(Undefined);
	FilterResponsibleOnChange(Undefined);
	FilterCompanyOnChange(Undefined);
	FilterNotPassedForExecutionOnChange(Undefined);
	FilterToBeScheduledOnChange(Undefined);
	FilterToBeRescheduledOnChange(Undefined);
	FilterCompletedOnChange(Undefined);
	FilterOverdueOnChange(Undefined);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshProductionOrderQueue" Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterStartDateOnChange(Item)
	
	SetElements = List.SettingsComposer.Settings.Filter.Items;
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(SetElements, NStr("en = 'StartDateFilter'; ru = 'StartDateFilter';pl = 'StartDateFilter';es_ES = 'StartDateFilter';es_CO = 'StartDateFilter';tr = 'StartDateFilter';it = 'StartDateFilter';de = 'StartDateFilter'"), DataCompositionFilterItemsGroupType.AndGroup);
	
	CommonClientServer.SetFilterItem(
		FilterGroup,
		"Start",
		FilterStartDate.StartDate,
		DataCompositionComparisonType.GreaterOrEqual,
		"StartDate",
		ValueIsFilled(FilterStartDate));
	
	CommonClientServer.AddCompositionItem(
		FilterGroup,
		"Start",
		DataCompositionComparisonType.LessOrEqual,
		FilterStartDate.EndDate,
		"EndDate",
		ValueIsFilled(FilterStartDate));
	
EndProcedure

&AtClient
Procedure FilterPriorityOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "Priority", FilterPriority, ValueIsFilled(FilterPriority));
EndProcedure

&AtClient
Procedure FilterDepartmentOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
EndProcedure

&AtClient
Procedure FilterResponsibleOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
EndProcedure

&AtClient
Procedure FilterCompanyOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
EndProcedure

&AtClient
Procedure FilterNotPassedForExecutionOnChange(Item)
	SetStateFilter();
EndProcedure

&AtClient
Procedure FilterToBeScheduledOnChange(Item)
	SetStateFilter();
EndProcedure

&AtClient
Procedure FilterToBeRescheduledOnChange(Item)
	SetStateFilter();
EndProcedure

&AtClient
Procedure FilterCompletedOnChange(Item)
	
	SetElements = List.SettingsComposer.Settings.Filter.Items;
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(SetElements,  NStr("en = 'Group completed'; ru = 'Группа завершено';pl = 'Grupa zakończona';es_ES = 'Grupo completado';es_CO = 'Grupo completado';tr = 'Grup tamamlandı';it = 'Gruppo completato';de = 'Gruppe abgeschlossen'"), DataCompositionFilterItemsGroupType.AndGroup);
	
	CommonClientServer.AddCompositionItem(
		FilterGroup,
		"StageGenerationIsRequired",
		DataCompositionComparisonType.Equal,
		3,
		"Completed",
		FilterCompleted);
	
EndProcedure

&AtClient
Procedure FilterOverdueOnChange(Item)
	
	SetElements = List.SettingsComposer.Settings.Filter.Items;
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(SetElements, NStr("en = 'Overdue'; ru = 'Просрочено';pl = 'Zaległe';es_ES = 'Vencido';es_CO = 'Vencido';tr = 'Vadesi geçmiş';it = 'In ritardo';de = 'Überfällig'"), DataCompositionFilterItemsGroupType.AndGroup);
	
	CommonClientServer.SetFilterItem(
		FilterGroup,
		"Finish",
		BegOfDay(CommonClient.SessionDate()),
		DataCompositionComparisonType.Less,
		NStr("en = 'Later than current date'; ru = 'Позже, чем текущая дата';pl = 'Później niż bieżąca data';es_ES = 'Después de la fecha actual';es_CO = 'Después de la fecha actual';tr = 'Güncel tarihten sonra';it = 'Successivo alla data corrente';de = 'Später als aktuelles Datum'"),
		FilterOverdue);
		
	OrFilterGroup = CommonClientServer.CreateFilterItemGroup(SetElements, NStr("en = 'Not completed'; ru = 'Не завершены';pl = 'Nie zakończone';es_ES = 'No se ha completado';es_CO = 'No se ha completado';tr = 'Tamamlanmadı';it = 'Non completato';de = 'Nicht abgeschlossen'"), DataCompositionFilterItemsGroupType.OrGroup);
	
	CommonClientServer.SetFilterItem(
		OrFilterGroup,
		"StageGenerationIsRequired",
		0,
		DataCompositionComparisonType.NotFilled,
		NStr("en = 'Do nothing'; ru = 'Без изменений';pl = 'Nic nie rób';es_ES = 'No hacer nada';es_CO = 'No hacer nada';tr = 'Hiçbir şey yapma';it = 'Non fare niente.';de = 'Nichts machen'"),
		FilterOverdue);
		
	CommonClientServer.AddCompositionItem(
		OrFilterGroup,
		"StageGenerationIsRequired",
		DataCompositionComparisonType.Less,
		3,
		NStr("en = 'Create or schedule'; ru = 'Создать или запланировать';pl = 'Utwórz lub zaplanuj';es_ES = 'Crear o programar';es_CO = 'Crear o programar';tr = 'Oluştur veya planla';it = 'Creare o pianificare';de = 'Erstellen oder planen'"),
		FilterOverdue);
	
EndProcedure

&AtClient
Procedure CollapseExpandFiltesPanelClick(Item)
	
	NewValueVisible = NOT Items.FilterSettingsAndAddInfo.Visible;
	WorkWithFiltersClient.CollapseExpandFiltesPanel(ThisObject, NewValueVisible);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OrderUp(Command)
	
	Order = Items.List.CurrentRow;
	
	If ValueIsFilled(Order) Then
		
		MoveOrderInQueue(Order, -1);
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OrderDown(Command)
	
	Order = Items.List.CurrentRow;
	
	If ValueIsFilled(Order) Then
		
		MoveOrderInQueue(Order, 1);
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OrdersBeingGenerated(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("OrderStateState", PredefinedValue("Enum.OrderStatuses.Open"));
	FormParameters.Insert("UseProductionPlanning", True);
	
	OpenForm("Document.ProductionOrder.ListForm", FormParameters);
	
EndProcedure

&AtClient
Procedure PassForExecution(Command)
	
	If Items.List.SelectedRows.Count() > 1 Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Cannot generate Work-in-progress for multiple Production orders at once. Select a single Production order and try again.'; ru = 'Не удается создать документ ""Незавершенное производство"" для нескольких заказов на производство одновременно. Выберите один заказ на производство и повторите попытку.';pl = 'Nie można wygenerować Pracy w toku dla kilku Zleceń produkcyjnych naraz. Wybierz jedno Zlecenie produkcyjne i spróbuj ponownie.';es_ES = 'No puede generar el trabajo en progreso para múltiples órdenes de producción a la vez. Seleccione una sola orden de producción e inténtelo de nuevo.';es_CO = 'No puede generar el trabajo en progreso para múltiples órdenes de producción a la vez. Seleccione una sola orden de producción e inténtelo de nuevo.';tr = 'Tek seferde birden fazla Üretim emri için İşlem bitişi oluşturulamaz. Tek bir Üretim emri seçip tekrar deneyin.';it = 'Impossibile generare Lavori in corso per Ordini di produzione multipli contemporaneamente. Selezionare un singolo ordine di produzione e riprovare.';de = 'Fehler beim Generieren der Arbeit In Bearbeitung gleichzeitig für mehrere Produktionsaufträge. Wählen Sie einen einzelnen Produktionsauftrag aus, und versuchen Sie es erneut.'"));
		
	ElsIf Items.List.SelectedRows.Count() = 1 Then
		
		FormParameters = New Structure("ProductionOrder", Items.List.SelectedRows[0]);
		OpenForm("Document.ProductionOrder.Form.PassingForExecution",
			FormParameters);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	NewConditionalAppearance = List.ConditionalAppearance.Items.Add();
	NewConditionalAppearance.Presentation = NStr("en = 'Overdue'; ru = 'Просрочено';pl = 'Zaległe';es_ES = 'Vencido';es_CO = 'Vencido';tr = 'Vadesi geçmiş';it = 'In ritardo';de = 'Überfällig'");
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Finish",
		BegOfDay(CurrentSessionDate()),
		DataCompositionComparisonType.Less);
		
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"StageGenerationIsRequired",
		3,
		DataCompositionComparisonType.Less);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "Finish");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", WebColors.DarkRed);
	
EndProcedure

&AtClient
Procedure SetStateFilter()
	
	FilterArray = New Array;
	
	If FilterNotPassedForExecution Then
		FilterArray.Add(1);
	EndIf;
	
	If FilterToBeScheduled Then
		FilterArray.Add(2);
	EndIf;
	
	If FilterToBeRescheduled Then
		FilterArray.Add(4);
	EndIf;
	
	DriveClientServer.SetListFilterItem(List, "StageGenerationIsRequired", FilterArray, FilterArray.Count() > 0, DataCompositionComparisonType.InList);
	
EndProcedure

&AtServerNoContext
Procedure MoveOrderInQueue(Order, Direction)
	
	If InformationRegisters.ProductionOrdersPriorities.OrderCanBeMoved(Order, Direction) Then
		
		InformationRegisters.ProductionOrdersPriorities.MoveOrderInQueue(Order, Direction);
		
	EndIf;
	
EndProcedure

#EndRegion

