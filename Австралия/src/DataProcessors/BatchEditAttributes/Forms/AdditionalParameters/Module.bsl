
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("ChangeInTransaction",    ChangeInTransaction);
	Parameters.Property("ProcessRecursively", ProcessRecursively);
	Parameters.Property("PortionSetting",        PortionSetting);
	Parameters.Property("ObjectsPercentageInPortion", ObjectsPercentageInPortion);
	Parameters.Property("ObjectCountInPortion",   ObjectCountInPortion);
	Parameters.Property("DeveloperMode",     DeveloperMode);
	Parameters.Property("DisableSelectionParameterConnections",     DisableSelectionParameterConnections);
	Parameters.Property("InterruptOnError",     InterruptOnError);
	
	HasDataAdministrationRight = AccessRight("DataAdministration", Metadata);
	WindowOptionsKey = ?(HasDataAdministrationRight, "HasDataAdministrationRight", "NoDataAdministrationRight");
	
	CanShowInternalAttributes = Not Parameters.ContextCall AND HasDataAdministrationRight;
	Items.ShowInternalAttributesGroup.Visible = CanShowInternalAttributes;
	Items.DeveloperMode.Visible = CanShowInternalAttributes;
	Items.DisableSelectionParameterConnections.Visible = CanShowInternalAttributes;
	
	If CanShowInternalAttributes Then
		Parameters.Property("ShowInternalAttributes", ShowInternalAttributes);
	EndIf;
	
	Items.ProcessRecursivelyGroup.Visible = Parameters.ContextCall AND Parameters.IncludeSubordinateItems;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetFormItems();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ChangeInTransactionOnChange(Item)
	
	SetFormItems();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	SelectionResult = New Structure;
	SelectionResult.Insert("ChangeInTransaction",    ChangeInTransaction);
	SelectionResult.Insert("ProcessRecursively", ProcessRecursively);
	SelectionResult.Insert("PortionSetting",        PortionSetting);
	SelectionResult.Insert("ObjectsPercentageInPortion", ObjectsPercentageInPortion);
	SelectionResult.Insert("ObjectCountInPortion",   ObjectCountInPortion);
	SelectionResult.Insert("InterruptOnError",     ChangeInTransaction Or InterruptOnError);
	SelectionResult.Insert("ShowInternalAttributes", ShowInternalAttributes);
	SelectionResult.Insert("DeveloperMode", DeveloperMode);
	SelectionResult.Insert("DisableSelectionParameterConnections", DisableSelectionParameterConnections);
	
	NotifyChoice(SelectionResult);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetFormItems()
	
	If ChangeInTransaction Then
		Items.AbortOnErrorGroup.Enabled = False;
	Else
		Items.AbortOnErrorGroup.Enabled = True;
	EndIf;
	
EndProcedure

#EndRegion
