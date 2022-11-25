
#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	Items.List.Representation = TableRepresentation.List;
	HierarchyOnActivateRowHandler();
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersHierarchy

&AtClient
Procedure HierarchyOnActivateRow(Item)
	
	AttachIdleHandler("HierarchyOnActivateRowHandler", 0.1, True);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure HierarchyOnActivateRowHandler()
	
	HierarchyFilter = Items.Hierarchy.CurrentRow;
	CommonClientServer.SetDynamicListFilterItem(
		List, "Parent", HierarchyFilter, 
		DataCompositionComparisonType.Equal, "Parent", True);
	
EndProcedure

#EndRegion
