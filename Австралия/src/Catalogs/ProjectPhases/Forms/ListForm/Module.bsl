
#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ProjectOnChange(Item)
	
	CommonClientServer.SetFilterItem(List.Filter, "Owner", Project);
	
EndProcedure

#EndRegion