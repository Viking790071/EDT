#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PictureIndicatorsInRowsClick(Item)
	
	TableType = 0;
	
EndProcedure

&AtClient
Procedure PictureIndicatorsInColumnsClick(Item)
	
	TableType = 1;
	
EndProcedure

&AtClient
Procedure PictureComplexTableClick(Item)
	
	TableType = 2;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CreateTable(Command)
	
	Close(TableType);
	
EndProcedure

#EndRegion
