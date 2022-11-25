
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SetConditionalAppearance();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
		For each FormItem In Items.CommandBar.ChildItems Do
			
			Items.Move(FormItem, Items.CommandBarForm);
			
		EndDo;
		
		CommonClientServer.SetFormItemProperty(Items, "CommandBar", "Visible", False);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	// Check whether the group is copied.
	If Clone AND IsFolder Then
		Cancel = True;
		
		ShowMessageBox(, NStr("ru='Добавление новых групп в справочнике запрещено.'; en = 'Adding new groups to catalog is prohibited.'; pl = 'Dodawanie nowych grup do katalogu jest zabronione.';es_ES = 'Está prohibido añadir nuevos grupos al catálogo.';es_CO = 'Está prohibido añadir nuevos grupos al catálogo.';tr = 'Kataloğa yeni grupların eklenmesi yasaktır.';it = 'L''aggiunta di nuovi gruppi alle anagrafiche è vietata.';de = 'Das Hinzufügen von neuen Gruppen in den Katalog ist verboten.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Items.List);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result) Export
	AttachableCommands.ExecuteCommand(ThisObject, Context, Items.List, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.AttachableCommands


#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Used");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	Item.Appearance.SetParameterValue("Visible", False);
	
EndProcedure

#EndRegion