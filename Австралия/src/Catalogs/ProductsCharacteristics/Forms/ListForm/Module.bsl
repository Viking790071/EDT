
&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CommonClientServer.SetFormItemProperty(Items, "FormCatalogProductsCharacteristicsVariantsGenerator", "Visible", False);
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Owner") Then
		
		OwnerObject = Parameters.Filter.Owner;
		
		If TypeOf(OwnerObject) = Type("CatalogRef.Products") Then
			
			Products = OwnerObject;
			
			If Not ValueIsFilled(OwnerObject)
				OR Not OwnerObject.ProductsType = Enums.ProductsTypes.InventoryItem
				AND Not OwnerObject.ProductsType = Enums.ProductsTypes.Service
				AND Not OwnerObject.ProductsType = Enums.ProductsTypes.Work Then
				
				AutoTitle = False;
				Title = NStr("en = 'Variants are stored only for inventory, services and work'; ru = 'Варианты хранятся только для запасов, услуг и работ';pl = 'Warianty są przechowywane tylko dla zapasów, usług i prac';es_ES = 'Variantes se almacenan solo para el inventario, los servicios y el trabajo';es_CO = 'Variantes se almacenan solo para el inventario, los servicios y el trabajo';tr = 'Varyantlar sadece stok, hizmetler ve işler için saklanır';it = 'Le varianti sono salvate solo per scorte, servizi e lavori';de = 'Varianten sind nur für Bestand, Dienstleistungen und Arbeiten gespeichert'");
				
				Items.List.ReadOnly = True;
				
			Else
				
				Owners = New Array;
				Owners.Add(OwnerObject);
				Owners.Add(Common.ObjectAttributeValue(OwnerObject, "ProductsCategory"));
				Parameters.Filter.Owner = Owners;
				
				CommonClientServer.SetFormItemProperty(Items, "FormCatalogProductsCharacteristicsVariantsGenerator", "Visible", True);
				
			EndIf;
			
			SetOfAdditAttributes = OwnerObject.ProductsCategory.SetOfCharacteristicProperties;
			
		ElsIf TypeOf(OwnerObject) = Type("CatalogRef.ProductsCategories") Then
			
			SetOfAdditAttributes = OwnerObject.SetOfCharacteristicProperties;
			
		Else
			
			Items.ChangeSetOfAdditionalAttributesAndInformation.Visible = False;
			
		EndIf;
		
	Else
		
		Items.ChangeSetOfAdditionalAttributesAndInformation.Visible = False;
		
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	Items.ChangeSetOfAdditionalAttributesAndInformation.Visible = 
		AccessRight("Edit", Metadata.Catalogs.AdditionalAttributesAndInfoSets);
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
// Procedure - event handler Execute Commands ChangeSetOfAdditionalAttributesAndInformation.
//
Procedure ChangeSetOfAdditionalAttributesAndInformation(Command)
	
	If ValueIsFilled(SetOfAdditAttributes) Then
		ParametersOfFormOfPropertiesSet = New Structure("Key", SetOfAdditAttributes);
		OpenForm("Catalog.AdditionalAttributesAndInfoSets.Form.ItemForm", ParametersOfFormOfPropertiesSet);
	Else
		ShowMessageBox(Undefined,NStr("en = 'Cannot receive the object property set. Perhaps, the necessary attributes are not filled in.'; ru = 'Нельзя получить набор свойств объекта. Возможно не заполнены необходимые реквизиты.';pl = 'Nie można odebrać zestawu właściwości obiektu. Możliwe, że niezbędne atrybuty nie są wprowadzone.';es_ES = 'No se puede recibir el conjunto de propiedades del objeto. Probablemente los atributos necesarios no se han rellenado.';es_CO = 'No se puede recibir el conjunto de propiedades del objeto. Probablemente los atributos necesarios no se han rellenado.';tr = 'Nesne özellikleri alınamıyor. Gereken öznitelikler doldurulmamış olabilir.';it = 'Non è possibile ottenere un insieme di proprietà dell''oggetto. Probabilmente i requisiti necessari non sono stati compilati.';de = 'Das Objekteigenschaftsset kann nicht empfangen werden. Vielleicht sind die notwendigen Attribute nicht ausgefüllt.'"));
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.SearchAndDeleteDuplicates

&AtClient
Procedure MergeSelected(Command)
	FindAndDeleteDuplicatesDuplicatesClient.MergeSelectedItems(Items.List);
EndProcedure

&AtClient
Procedure ShowUsage(Command)
	FindAndDeleteDuplicatesDuplicatesClient.ShowUsageInstances(Items.List);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshProductsCharacteristics" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

// End StandardSubsystems.SearchAndDeleteDuplicates

#EndRegion
