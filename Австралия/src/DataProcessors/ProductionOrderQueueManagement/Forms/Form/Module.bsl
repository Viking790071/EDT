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
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(SetElements,  NStr("en = 'Group completed'; ru = '???????????? ??????????????????';pl = 'Grupa zako??czona';es_ES = 'Grupo completado';es_CO = 'Grupo completado';tr = 'Grup tamamland??';it = 'Gruppo completato';de = 'Gruppe abgeschlossen'"), DataCompositionFilterItemsGroupType.AndGroup);
	
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
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(SetElements, NStr("en = 'Overdue'; ru = '????????????????????';pl = 'Zaleg??e';es_ES = 'Vencido';es_CO = 'Vencido';tr = 'Vadesi ge??mi??';it = 'In ritardo';de = '??berf??llig'"), DataCompositionFilterItemsGroupType.AndGroup);
	
	CommonClientServer.SetFilterItem(
		FilterGroup,
		"Finish",
		BegOfDay(CommonClient.SessionDate()),
		DataCompositionComparisonType.Less,
		NStr("en = 'Later than current date'; ru = '??????????, ?????? ?????????????? ????????';pl = 'P????niej ni?? bie????ca data';es_ES = 'Despu??s de la fecha actual';es_CO = 'Despu??s de la fecha actual';tr = 'G??ncel tarihten sonra';it = 'Successivo alla data corrente';de = 'Sp??ter als aktuelles Datum'"),
		FilterOverdue);
		
	OrFilterGroup = CommonClientServer.CreateFilterItemGroup(SetElements, NStr("en = 'Not completed'; ru = '???? ??????????????????';pl = 'Nie zako??czone';es_ES = 'No se ha completado';es_CO = 'No se ha completado';tr = 'Tamamlanmad??';it = 'Non completato';de = 'Nicht abgeschlossen'"), DataCompositionFilterItemsGroupType.OrGroup);
	
	CommonClientServer.SetFilterItem(
		OrFilterGroup,
		"StageGenerationIsRequired",
		0,
		DataCompositionComparisonType.NotFilled,
		NStr("en = 'Do nothing'; ru = '?????? ??????????????????';pl = 'Nic nie r??b';es_ES = 'No hacer nada';es_CO = 'No hacer nada';tr = 'Hi??bir ??ey yapma';it = 'Non fare niente.';de = 'Nichts machen'"),
		FilterOverdue);
		
	CommonClientServer.AddCompositionItem(
		OrFilterGroup,
		"StageGenerationIsRequired",
		DataCompositionComparisonType.Less,
		3,
		NStr("en = 'Create or schedule'; ru = '?????????????? ?????? ??????????????????????????';pl = 'Utw??rz lub zaplanuj';es_ES = 'Crear o programar';es_CO = 'Crear o programar';tr = 'Olu??tur veya planla';it = 'Creare o pianificare';de = 'Erstellen oder planen'"),
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
		
		CommonClientServer.MessageToUser(NStr("en = 'Cannot generate Work-in-progress for multiple Production orders at once. Select a single Production order and try again.'; ru = '???? ?????????????? ?????????????? ???????????????? ""?????????????????????????? ????????????????????????"" ?????? ???????????????????? ?????????????? ???? ???????????????????????? ????????????????????????. ???????????????? ???????? ?????????? ???? ???????????????????????? ?? ?????????????????? ??????????????.';pl = 'Nie mo??na wygenerowa?? Pracy w toku dla kilku Zlece?? produkcyjnych naraz. Wybierz jedno Zlecenie produkcyjne i spr??buj ponownie.';es_ES = 'No puede generar el trabajo en progreso para m??ltiples ??rdenes de producci??n a la vez. Seleccione una sola orden de producci??n e int??ntelo de nuevo.';es_CO = 'No puede generar el trabajo en progreso para m??ltiples ??rdenes de producci??n a la vez. Seleccione una sola orden de producci??n e int??ntelo de nuevo.';tr = 'Tek seferde birden fazla ??retim emri i??in ????lem biti??i olu??turulamaz. Tek bir ??retim emri se??ip tekrar deneyin.';it = 'Impossibile generare Lavori in corso per Ordini di produzione multipli contemporaneamente. Selezionare un singolo ordine di produzione e riprovare.';de = 'Fehler beim Generieren der Arbeit In Bearbeitung gleichzeitig f??r mehrere Produktionsauftr??ge. W??hlen Sie einen einzelnen Produktionsauftrag aus, und versuchen Sie es erneut.'"));
		
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
	NewConditionalAppearance.Presentation = NStr("en = 'Overdue'; ru = '????????????????????';pl = 'Zaleg??e';es_ES = 'Vencido';es_CO = 'Vencido';tr = 'Vadesi ge??mi??';it = 'In ritardo';de = '??berf??llig'");
	
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

