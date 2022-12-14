
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("UseFilledSKU") Then
		UseFilledSKU = Parameters.UseFilledSKU;
	EndIf;
		
	If Not Parameters.Filter.Property("Products") Then
		Items.SetAsDefaultSupplierProduct.Visible = False;
		Items.FormClearDefault.Visible = False;
	Else 
		Product = Parameters.Filter.Products; 
		SetEnabledOfClearDefaultButton();
	EndIf;
	
	// StandardSubsystems.BatchObjectModification
	Items.ChangeSelected.Visible = AccessRight("Edit", Metadata.Catalogs.SuppliersProducts);
	// End StandardSubsystems.BatchObjectModification
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// Set conditional appearance
	SetConditionalAppearance();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SupplierProductSetAsDefault" Then
		Items.List.Refresh();
		SetEnabledOfClearDefaultButton();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ClearDefault(Command)
	
	If Not ValueIsFilled(Product) Then
		Return;
	EndIf;
	
	ClearByDefaultAtServer();
	
	Items.List.Refresh();
	
	Notify("SupplierProductClearByDefault", Product);
	
EndProcedure

#EndRegion

#Region Private

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

// End StandardSubsystems.SearchAndDeleteDuplicates

// StandardSubsystems.BatchObjectModification

&AtClient
Procedure ChangeSelected(Command)
	BatchEditObjectsClient.ChangeSelectedItems(Items.List);
EndProcedure

// End StandardSubsystems.BatchObjectModification

#EndRegion

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearanceOfList	= List.SettingsComposer.Settings.ConditionalAppearance;
	
	ItemAppearance = ConditionalAppearanceOfList.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("IsDefault");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", New Font(,,True,));
	
	ItemAppearance.ViewMode			= DataCompositionSettingsItemViewMode.Inaccessible;
	ItemAppearance.UserSettingID	= "Preset";
	ItemAppearance.Presentation		= NStr("en = 'Highlight default product cross-reference'; ru = '???????????????? ???????????????????????? ?????????????????????? ???? ??????????????????';pl = 'Pod??wietl domy??lne powi??zane informacje o produkcie';es_ES = 'Destacar la referencia cruzada del producto por defecto';es_CO = 'Destacar la referencia cruzada del producto por defecto';tr = 'Varsay??lan ??r??n ??apraz referans??n?? vurgula';it = 'Evidenziare riferimento incrociato predefinito dell''articolo';de = 'Standard-Produktherstellartikelnummer hervorheben'");
	
EndProcedure

&AtServer
Procedure SetEnabledOfClearDefaultButton()
	
	IsEnabledClearDefault = ValueIsFilled(Common.ObjectAttributeValue(Product, "ProductCrossReference"));
	
	Items.FormClearDefault.Enabled = IsEnabledClearDefault;
	
EndProcedure

&AtServer
Procedure ClearByDefaultAtServer()
	
	DefaultProductCrossReference = Common.ObjectAttributeValue(Product, "ProductCrossReference");
	
	If Not ValueIsFilled(DefaultProductCrossReference) Then
		Return;
	EndIf;
	
	ObjectProduct = Product.GetObject();
	
	ObjectProduct.UseDefaultCrossReference	= False;
	
	Try
		
		ObjectProduct.Write();
		
	Except
		
		MessageText = NStr("en = 'Cannot clear the default product cross-reference. Close all windows and try again.'; ru = '???? ?????????????? ???????????????? ???????????????? ???????????????????????? ???????????????????? ???? ??????????????????. ???????????????? ?????? ???????? ?? ???????????????????? ??????????.';pl = 'Nie mo??na wyczy??ci?? domy??lnych powi??zanych informacji o produkcie. Zamknij wszystkie okna i spr??buj ponownie.';es_ES = 'No se puede borrar la referencia cruzada del producto por defecto. Cierre todas las ventanas e int??ntelo de nuevo.';es_CO = 'No se puede borrar la referencia cruzada del producto por defecto. Cierre todas las ventanas e int??ntelo de nuevo.';tr = 'Varsay??lan ??r??n ??apraz referans?? silinemiyor. T??m pencereleri kapat??n ve tekrar deneyin.';it = 'Impossibile cancellare il riferimento incrociato predefinito dell''articolo. Chiudere tutte le finestre e riprovare.';de = 'Der Standardproduktquerverweis kann nicht gel??scht werden. Schlie??en Sie alle Fenster und versuchen Sie es erneut.'");
		CommonClientServer.MessageToUser(MessageText);
		
	EndTry;
	
	SetEnabledOfClearDefaultButton();
	
EndProcedure

#EndRegion
