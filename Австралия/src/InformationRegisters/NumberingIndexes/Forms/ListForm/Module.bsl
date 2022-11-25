#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillTypesList(ObjectsTypes);
	List.Parameters.SetParameterValue("Type", TypeOf(Undefined));
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ObjectsTypesOnActivateRow(Item)
	
	If Items.ObjectsTypes.CurrentRow <> Undefined Then
		AttachIdleHandler("IdleHandler", 0.2, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	Cancel = True;
	ObjectType = ObjectsTypes.FindByID(Items.ObjectsTypes.CurrentRow).Value;
	
	FormParameters = New Structure;
	FormParameters.Insert("ObjectType", ObjectType);
	If Clone Then 
		FormParameters.Insert("CopyingValue", Items.List.CurrentRow);
	EndIf;
	
	OpenForm("InformationRegister.NumberingIndexes.RecordForm", FormParameters, Items.List);
	
EndProcedure

#EndRegion


#Region Private

&AtServer
Procedure FillTypesList(TypesList) 
	
	InformationRegisters.NumberingIndexes.FillTypesList(TypesList);
	
EndProcedure

&AtClient
Procedure IdleHandler()
	
	ObjectType = ObjectsTypes.FindByID(Items.ObjectsTypes.CurrentRow).Value;
	If ObjectType <> List.Parameters.Items.Find("Type").Value Then
		List.Parameters.SetParameterValue("Type", ObjectType);
	EndIf;
	
EndProcedure

#EndRegion