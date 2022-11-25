
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region WorksAndServicesFormTableItemsEventHandlers

&AtClient
Procedure WorksAndServicesProductsOnChange(Item)
	
	Row = Items.WorksAndServices.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", Row.Products);
	
	StructureData = GetDataProductsOnChange(StructureData, CurrentDate());
	
	If StructureData.Property("Specification") Then
		Row.Specification = StructureData.Specification;
	EndIf;
	
EndProcedure


&AtClient
Procedure WorksAndServicesSpecificationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Item.Parent.CurrentData;
	ProductOwner = CurrentData.Products;
	
	ParametersFormBOM = New Structure("DateChoice, Filter", 
		CurrentDate(),
		New Structure("Owner, Status", 
			ProductOwner, 
			PredefinedValue("Enum.BOMStatuses.Active")));
		
	ChoiceHandler = New NotifyDescription("WorksAndServicesSpecificationStartChoiceEnd", 
		ThisObject, 
		New Structure("CurrentData", CurrentData));
	
	OpenForm("Catalog.BillsOfMaterials.ChoiceForm", ParametersFormBOM, ThisObject, , , , ChoiceHandler);
	
EndProcedure

&AtClient
Procedure WorksAndServicesSpecificationStartChoiceEnd(ResultValue, AdditionalParameters) Export
	
	If ResultValue = Undefined Then
		Return;
	EndIf;
	
	AdditionalParameters.CurrentData.Specification = ResultValue;
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
// Receives the set of data from the server for the WorksAndServicesProductsOnChange procedure.
//
Function GetDataProductsOnChange(StructureData, WorksAndServicesDate = Undefined)
	
	StructureProduct = Common.ObjectAttributesValues(StructureData.Products, 
		"Description, ProductsType");
	
	If Not WorksAndServicesDate = Undefined 
		And StructureProduct.ProductsType = Enums.ProductsTypes.Work Then
		
		StructureData.Insert("Specification", Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products, WorksAndServicesDate));
		
	EndIf;
	
	Return StructureData;
	
EndFunction

#EndRegion
