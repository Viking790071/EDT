#Region FormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Owner") Then
		
		Products = Parameters.Filter.Owner;
		
		UseProductionSubsystem = Constants.UseProductionSubsystem.Get();
		UseWorkOrders = Constants.UseWorkOrders.Get();
		UseKitProcessing = Constants.UseKitProcessing.Get();
		
		If Not ValueIsFilled(Products)
			OR Products.ProductsType = Enums.ProductsTypes.Service Then
			
			AutoTitle = False;
			If UseProductionSubsystem AND UseWorkOrders Then
				Title = NStr("en = 'BOMs are stored for inventory and work only'; ru = 'Спецификации хранятся только для запасов и работ.';pl = 'Specyfikacje materiałowe są przechowywane tylko dla magazynów i pracy';es_ES = 'BOMs se almacenan solo para inventario y trabajo';es_CO = 'BOMs se almacenan solo para inventario y trabajo';tr = 'Ürün reçeteleri sadece stok ve çalışma için saklanır';it = 'Le Distinte Base sono salvate solo per scorte e lavori';de = 'Stücklisten werden nur für den Bestand und die Arbeit gespeichert'");
			ElsIf UseProductionSubsystem Then
				Title = NStr("en = 'BOMs are stored for inventory only'; ru = 'Спецификации хранятся только для запасов';pl = 'Zestawienia materiałowe są przechowywane tylko dla magazynów';es_ES = 'Los BOM se almacenan solo para el inventario';es_CO = 'Los BOM se almacenan solo para el inventario';tr = 'Ürün reçeteleri sadece stok için saklanır';it = 'Le Distinte Base sono salvate solo per le scorte';de = 'Stücklisten werden nur für den Bestand gespeichert'");
			Else
				Title = NStr("en = 'BOMs are stored for work only'; ru = 'Спецификации хранятся только для работ.';pl = 'Specyfikacje materiałowe są przechowywane tylko dla pracy';es_ES = 'BOMs se almacenan solo para el trabajo';es_CO = 'BOMs se almacenan solo para el trabajo';tr = 'Ürün reçeteleri sadece çalışma için saklanır';it = 'Le Distinte Base sono salvate solo per lavori';de = 'Stücklisten werden nur für die Arbeit gespeichert'");
			EndIf;
			Items.List.ReadOnly = True;
			
		ElsIf Products.ProductsType = Enums.ProductsTypes.InventoryItem And Not UseProductionSubsystem And Not UseKitProcessing Then
			
			AutoTitle = False;
			Title = NStr("en = 'BOMs are stored for works only'; ru = 'Спецификации хранятся только для работ';pl = 'Zestawienia materiałowe są przechowywane tylko dla prac';es_ES = 'BOMs se almacenan solo para trabajos';es_CO = 'BOMs se almacenan solo para trabajos';tr = 'Ürün reçeteleri sadece çalışmalar için saklanır';it = 'Le Distinte Base sono salvate solo per i lavori';de = 'Stücklisten werden nur für Arbeiten gespeichert'");
			Items.List.ReadOnly = True;
			
		ElsIf Products.ProductsType = Enums.ProductsTypes.Work AND Not UseWorkOrders Then
			
			AutoTitle = False;
			Title = NStr("en = 'BOMs are stored for inventory only'; ru = 'Спецификации хранятся только для запасов';pl = 'Zestawienia materiałowe są przechowywane tylko dla magazynów';es_ES = 'Los BOM se almacenan solo para el inventario';es_CO = 'Los BOM se almacenan solo para el inventario';tr = 'Ürün reçeteleri sadece stok için saklanır';it = 'Le Distinte Base sono salvate solo per le scorte';de = 'Stücklisten werden nur für den Bestand gespeichert'");
			Items.List.ReadOnly = True;
			
		EndIf;
		
	Else
		
		Items.SetAsDefaultBOM.Visible = False;
		
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// Set conditional appearance
	SetConditionalAppearance();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
	IsDriveLite = Constants.DriveTrade.Get();
	Items.OperationKind.Visible = Not IsDriveLite;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "BOMSetAsDefault" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearanceOfList	= List.SettingsComposer.Settings.ConditionalAppearance;
	
	ColorGray = WebColors.Silver;
	
	ListOfStatuses = New ValueList;
	ListOfStatuses.Add(Enums.BOMStatuses.Closed);
	ListOfStatuses.Add(Enums.BOMStatuses.Open);
	
	ItemAppearance = ConditionalAppearanceOfList.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Status");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.InList;
	DataFilterItem.RightValue		= ListOfStatuses;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorGray);
	
	// Default - bold
	ItemAppearance = ConditionalAppearanceOfList.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("IsDefault");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", New Font(,,True,));
	
	ItemAppearance.ViewMode			= DataCompositionSettingsItemViewMode.Inaccessible;
	ItemAppearance.UserSettingID	= "Preset";
	ItemAppearance.Presentation		= NStr("en = 'BOM by default'; ru = 'Спецификация по умолчанию';pl = 'Specyfikacja materiałowa domyślnie';es_ES = 'BOM por defecto';es_CO = 'BOM por defecto';tr = 'Varsayılan ürün reçetesi';it = 'Distinta Base da impostazione predefinita';de = 'Standardstückliste'");
	
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

// End StandardSubsystems.SearchAndDeleteDuplicates

#EndRegion

#EndRegion
