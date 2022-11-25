#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler ChoiceDataReceivingProcessing.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Not Parameters.Property("Recursion")
		AND Parameters.Filter.Property("Owner") AND TypeOf(Parameters.Filter.Owner) = Type("CatalogRef.Products") Then
		// When first entering if selection parameter link is set by
		// products value then add selection parameters by the selection on owner - products categories according to the hierarchy.
		
		StandardProcessing = False;
		
		Products 		 = Parameters.Filter.Owner;
		ProductsCategory = Parameters.Filter.Owner.ProductsCategory;
		
		FilterArray = New Array;
		FilterArray.Add(Products);
		FilterArray.Add(ProductsCategory);
		
		Parent = ProductsCategory.Parent;
		While ValueIsFilled(Parent) Do
			FilterArray.Add(Parent);
			Parent = Parent.Parent;
		EndDo;
		
		Parameters.Filter.Insert("Owner", FilterArray);
		
		// Flag of repeated logon.
		Parameters.Insert("Recursion");
		
		// Get standard selection list with respect to added filter.
		StandardList = GetChoiceData(Parameters);
		
		If Not (Parameters.Property("DontUseClassifier") AND Parameters.DontUseClassifier = True) Then
			If ValueIsFilled(Parameters.Filter.Owner) Then
			// Add standard list by basic products UOM according to the classifier.
				LocalizedDescription = "Description" + NativeLanguagesSupportServer.CurrentLanguageSuffix();
				PresentationUOM = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (storage unit)'; ru = '%1 (ед. хранения)';pl = '%1 (jednostka przechowywania)';es_ES = '%1 (unidad de almacenamiento)';es_CO = '%1 (unidad de almacenamiento)';tr = '%1 (saklama birimi)';it = '%1 (unità di memorizzazione)';de = '%1 (Speichereinheit)'"),
					Products.MeasurementUnit[LocalizedDescription]);
				StandardList.Insert(0, Products.MeasurementUnit, 
					New FormattedString(PresentationUOM, New Font(,,True)));
			Else
				CommonClientServer.MessageToUser(NStr("en = 'Products are not filled in.'; ru = 'Не заполнена номенклатура!';pl = 'Produkty nie są wprowadzone.';es_ES = 'Productos no se han rellenado.';es_CO = 'Productos no se han rellenado.';tr = 'Ürünler doldurulmadı.';it = 'Gli articoli non sono compilati.';de = 'Produkte sind nicht ausgefüllt.'"));
			EndIf;
		EndIf;
		
		ChoiceData = StandardList;
		
	Else
		
		NativeLanguagesSupportServer.ChoiceDataGetProcessing(
			ChoiceData,
			Parameters,
			StandardProcessing,
			Metadata.Catalogs.UOM);
		
	EndIf;
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Private

#Region LibrariesHandlers

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("Description");
	AttributesToLock.Add("Factor");
	AttributesToLock.Add("Owner");
	AttributesToLock.Add("Weight");
	
	Return AttributesToLock;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#Region CloneProductRelatedData

Procedure MakeRelatedAdditionalUOM(ProductReceiver, ProductSource) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	UOM.Ref AS UOM
		|FROM
		|	Catalog.UOM AS UOM
		|WHERE
		|	UOM.Owner = &ProductSource";
	
	Query.SetParameter("ProductSource", ProductSource);
	
	QueryResult = Query.Execute();
	
	SelectionUOM = QueryResult.Select();
	
	While SelectionUOM.Next() Do
		UOMReceiver = SelectionUOM.UOM.Copy();
		UOMReceiver.Owner = ProductReceiver;
		UOMReceiver.Write();
	EndDo;
	
EndProcedure

#EndRegion

#EndIf