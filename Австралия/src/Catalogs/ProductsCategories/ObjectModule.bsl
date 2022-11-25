#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not UseBatches Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BatchSettings");
	EndIf;
	
EndProcedure

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Cancel Then
		
		WriteAdditionalAttributesCatalog(PropertySet, Catalogs.AdditionalAttributesAndInfoSets.Catalog_Products);
		WriteAdditionalAttributesCatalog(SetOfCharacteristicProperties, Catalogs.AdditionalAttributesAndInfoSets.Catalog_ProductsCharacteristics);
		
	EndIf;	
	
EndProcedure

// Procedure - event handler  AtCopy.
//
Procedure OnCopy(CopiedObject)
	
	PropertySet						= Undefined;
	SetOfCharacteristicProperties	= Undefined;
	UseMatrixSelectionForm			= False;
	
EndProcedure

#EndRegion

#Region Private

Procedure WriteAdditionalAttributesCatalog(SetOfProperties, SetParent)
	
	If Not ValueIsFilled(SetOfProperties) Then
		ObjectSet = Catalogs.AdditionalAttributesAndInfoSets.CreateItem();
	Else
		ObjectSet = SetOfProperties.GetObject();
		LockDataForEdit(ObjectSet.Ref);
	EndIf;
	
	ObjectSet.Description	= Description;
	ObjectSet.Parent		= SetParent;
	ObjectSet.DeletionMark	= DeletionMark;
	ObjectSet.Used			= True;
	ObjectSet.Write();
	SetOfProperties = ObjectSet.Ref;

EndProcedure

#EndRegion

#EndIf