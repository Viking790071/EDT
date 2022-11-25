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
	
	SetConditionalAppearance();
	
	SetFilter(New Structure("ShowCompletedItems", ShowCompletedItems));
	CommonClientServer.SetDynamicListFilterItem(
		List, "Author", Users.CurrentUser());
	BusinessProcessesAndTasksServer.SetBusinessProcessesAppearance(List.ConditionalAppearance);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_PerformerTask" Then
		Items.List.Refresh();
	EndIf;
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	SetFilter(Settings);
		
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowCompletedItemsOnChange(Item)
	
	SetFilter(New Structure("ShowCompletedItems", ShowCompletedItems));
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	If Items.List.CurrentData <> Undefined Then
		ShowValue(,Items.List.CurrentData.BusinessProcess);
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	
	If Item.CurrentData <> Undefined Then
		ShowValue(,Item.CurrentData.BusinessProcess);
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DeletionMark(Command)
	BusinessProcessesAndTasksClient.BusinessProcessesListDeletionMark(Items.List);
EndProcedure

&AtClient
Procedure BusinessProcessTasks(Command)
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenForm("Task.PerformerTask.Form.TasksByBusinessProcess",
		New Structure("FilterValue", Items.List.CurrentData.BusinessProcess));
EndProcedure

&AtClient
Procedure Flowchart(Command)
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenForm("DataProcessor.BusinessProcessFlowchart.Form", 
		New Structure("BusinessProcess", Items.List.CurrentData.BusinessProcess));
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetFilter(FilterParameters)
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "Completed", False,,, Not FilterParameters["ShowCompletedItems"]);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	List.ConditionalAppearance.Items.Clear();
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Completed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.CompletedBusinessProcess);
	
EndProcedure

#EndRegion
