
#Region FormEventsHandlers

// Procedure - OnCreateAtServer form event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.DocumentRef = Undefined Then
		Raise NStr("en = 'The report can be opened only from documents.'; ru = 'Открытие отчета предусмотрено только из документов.';pl = 'Raport może zostać otworzony tylko z dokumentów.';es_ES = 'El informe puede abrirse solo desde los documentos.';es_CO = 'El informe puede abrirse solo desde los documentos.';tr = 'Rapor sadece belgelerden açılabilir.';it = 'L''apertura del report è fornita solo dai documenti.';de = 'Der Bericht kann nur aus Dokumenten geöffnet werden.'");
	EndIf;
	
	DocumentRef = Parameters.DocumentRef;
	
	DiscountsAreCalculated = DocumentRef.DiscountsAreCalculated;
	
	ThisObject.AutoTitle = False;
	SubTitle = NStr("en = 'Automatic discounts applied in the document'; ru = 'Автоматические скидки, примененные в документе';pl = 'Zastosowano rabaty automatyczne w dokumencie';es_ES = 'Descuentos automáticos aplicados en el documento';es_CO = 'Descuentos automáticos aplicados en el documento';tr = 'Belgede uygulanan otomatik indirimler';it = 'Sconti automatici applicati nel documento';de = 'Automatische Rabatte, die im Beleg angewendet werden'");
	ThisObject.Title = SubTitle + StringFunctionsClientServer.SubstituteParametersToString(": <%1>", DocumentRef);
	
	Generate();
	
EndProcedure

// Procedure - OnOpen form event handler.
//
&AtClient
Procedure OnOpen(Cancel)
	
	If TypeOf(FormOwner) = Type("ClientApplicationForm") Then
		If FormOwner.Modified Then
			Items.WarningDecoration.Visible = True;
		Else
			Items.WarningDecoration.Visible = False;
		EndIf;
	EndIf;
	
	DiscountsAreNotCalculatedText =  NStr("en = 'Please post the document before generating the report.'; ru = 'Перед формированием отчета необходимо провести документы';pl = 'Zatwierdź dokument przed wygenerowaniem raportu.';es_ES = 'Por favor, envíe el documento antes de generar el informe.';es_CO = 'Por favor, envíe el documento antes de generar el informe.';tr = 'Lütfen raporu oluşturmadan önce belgeyi yayınlayın.';it = 'Si prega di pubblicare il documento prima di generare il report.';de = 'Bitte buchen Sie das Dokument, bevor Sie den Bericht generieren.'");
	If Not DiscountsAreCalculated Then
		If Items.WarningDecoration.Visible Then
			Items.WarningDecoration.Title = Items.WarningDecoration.Title + " " + DiscountsAreNotCalculatedText;
		Else
			Items.WarningDecoration.Visible = True;
			Items.WarningDecoration.Title = DiscountsAreNotCalculatedText;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Refresh(Command)
	
	Generate();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure RecursiveDiscountsBypass(DiscountsTree, DiscountsArray)
	
	For Each TreeRow In DiscountsTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			RecursiveDiscountsBypass(TreeRow, DiscountsArray);
			
		Else
			
			DiscountsArray.Add(TreeRow);
		
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Function GetAutomaticDiscountCalculationParametersStructureServer(SalesInvoiceRef)

	OrderParametersStructure = New Structure("SalesByOrders, SalesExceedingOrder", False, False);
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	SalesInvoiceInventory.Order AS Order
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|WHERE
	|	SalesInvoiceInventory.Ref = &Ref
	|
	|GROUP BY
	|	SalesInvoiceInventory.Order";
	
	Query.SetParameter("Ref", SalesInvoiceRef);
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		If ValueIsFilled(Selection.Order) Then
			OrderParametersStructure.SalesByOrders = True;
		Else
			OrderParametersStructure.SalesExceedingOrder = True;
		EndIf;
	EndDo;
	
	Return OrderParametersStructure;
	
EndFunction

&AtServer
Procedure Generate()
	
	SpreadsheetDocument.Clear();
	
	DocumentObject = DocumentRef.GetObject();
	
	Template = Reports.DiscountsAppliedInDocument.GetTemplate("Template");
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",				False);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",	False);
	
	TSName = "Inventory";
	
	FixedTop = 1;
	
	If TypeOf(DocumentObject) = Type("DocumentObject.SalesInvoice") Then
		
		AutomaticDiscountsCalculationParametersStructure = GetAutomaticDiscountCalculationParametersStructureServer(DocumentObject.Ref);
		
		DisplayAdditionalMessage = True;
		If AutomaticDiscountsCalculationParametersStructure.SalesByOrders AND Not AutomaticDiscountsCalculationParametersStructure.SalesExceedingOrder Then
			AdditionalMessageText = NStr("en = 'Discounts are calculated based on order data.'; ru = 'Скидки рассчитаны по данным заказа.';pl = 'Rabaty są obliczane na podstawie danych zamówienia.';es_ES = 'Los descuentos son calculados basados en los datos de orden.';es_CO = 'Los descuentos son calculados basados en los datos de orden.';tr = 'İndirimler sipariş verilerine göre hesaplanmaktadır.';it = 'Gli sconti sono calcolati sulla base dei dati dell''ordine.';de = 'Die Rabatte werden auf der Grundlage der Auftragsdaten berechnet.'");
		ElsIf AutomaticDiscountsCalculationParametersStructure.SalesByOrders AND AutomaticDiscountsCalculationParametersStructure.SalesExceedingOrder Then
			AdditionalMessageText = NStr("en = 'Discounts are calculated based on order data. Strings over the order are calculated separately.'; ru = 'Скидки рассчитаны по данным заказа. Остальные строки были рассчитаны отдельно.';pl = 'Rabaty są obliczane na podstawie danych zamówienia. Wierszy nad zamówieniem są obliczane oddzielnie.';es_ES = 'Los descuentos son calculados basados en los datos de orden. Las líneas en la orden son calculadas separadamente.';es_CO = 'Los descuentos son calculados basados en los datos de orden. Las líneas en la orden son calculadas separadamente.';tr = 'İndirimler sipariş verilerine göre hesaplanmaktadır. Siparişin üzerindeki dizgiler ayrı ayrı hesaplanır.';it = 'Gli sconti sono calcolati sulla base dei dati di ordine. Le stringhe sopra l''ordine sono calcolate in maniera separata.';de = 'Die Rabatte werden auf der Grundlage der Auftragsdaten berechnet. Zeichenfolgen über der Bestellung werden separat berechnet.'");			
		Else
			DisplayAdditionalMessage = False;
		EndIf;
		If DisplayAdditionalMessage Then
			AdditionalMessageArea = Template.GetArea("RealizationOnClientRequest");
			AdditionalMessageArea.Parameters.AdditionalMessage = AdditionalMessageText;
			SpreadsheetDocument.Put(AdditionalMessageArea);
			FixedTop = 2;
		Else
			FixedTop = 1;
		EndIf;
		
	EndIf;
	
	If TypeOf(DocumentObject) = Type("DocumentObject.Quote") Then
		FixedTop = 1;
	EndIf;
	
	ProductsCharacteristicsUsage = GetFunctionalOption("UseCharacteristics");
	
	AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(DocumentObject, ParameterStructure);
	
	DiscountsArray = New Array;
	RecursiveDiscountsBypass(AppliedDiscounts.DiscountsTree, DiscountsArray);
	
	AreaHeaderProducts             = Template.GetArea("Header|Products");
	AreaHeaderCharacteristic       = Template.GetArea("Header|Characteristic");
	AreaHeaderAmountAndCompleted   = Template.GetArea("Header|AmountAndCompleted");
	
	AreaStringProducts             = Template.GetArea("String|Products");
	AreaStringCharacteristic       = Template.GetArea("String|Characteristic");
	AreaStringAmountAndCompleted   = Template.GetArea("String|AmountAndCompleted");
	
	AreaTotalProducts              = Template.GetArea("StringTotal|Products");
	AreaTotalCharacteristic        = Template.GetArea("StringTotal|Characteristic");
	AreaTotalAmountAndCompleted    = Template.GetArea("StringTotal|AmountAndCompleted");
	
	AreaLegend                     = Template.GetArea("Legend|Products");
	
	// Report header
	SpreadsheetDocument.Put(AreaHeaderProducts);
	If ProductsCharacteristicsUsage Then
		SpreadsheetDocument.Join(AreaHeaderCharacteristic);
	EndIf;
	SpreadsheetDocument.Join(AreaHeaderAmountAndCompleted);
	
	SpreadsheetDocument.FixedTop = FixedTop;
	
	ConditionsFulfilmentAccordance = New Map;
	
	For Each ProductsRow In DocumentObject[TSName] Do

		
		AreaStringProducts.Parameters.Products = ProductsRow.Products;
		AreaStringProducts.Parameters.LineNumber  = ProductsRow.LineNumber;
		SpreadsheetDocument.Put(AreaStringProducts);
		If ProductsCharacteristicsUsage Then
			AreaStringCharacteristic.Parameters.Characteristic = ProductsRow.Characteristic;
			SpreadsheetDocument.Join(AreaStringCharacteristic);
		EndIf;
		AreaStringAmountAndCompleted.Parameters.Amount = ProductsRow.AutomaticDiscountAmount;
		SpreadsheetDocument.Join(AreaStringAmountAndCompleted);
		
		SpreadsheetDocument.StartRowGroup("Products", True);
		For Each TreeRow In DiscountsArray Do
			
			CurAttributeConnectionKey = "ConnectionKey";
			
			// Discount conditions
			AllConditionsFulfilled = True;
			For Each RowCondition In TreeRow.ConditionsParameters.TableConditions Do
				
				If RowCondition.RestrictionArea = Enums.DiscountApplyingArea.AtRow Then
					FoundConditionsCheckingTableRows = TreeRow.ConditionsParameters.ConditionsByLine.ConditionsCheckingTable.Find(ProductsRow[CurAttributeConnectionKey], "ConnectionKey");
					If FoundConditionsCheckingTableRows <> Undefined Then
						ColumnName = TreeRow.ConditionsParameters.ConditionsByLine.MatchConditionTableColumnsWithConditionsCheckingTable.Get(RowCondition.AssignmentCondition);
						If ColumnName <> Undefined Then
							ConditionExecuted = FoundConditionsCheckingTableRows[ColumnName];
						EndIf;
					Else
						ConditionExecuted = False;
					EndIf;
				Else
					ConditionExecuted = RowCondition.Completed;
				EndIf;
				ConditionsFulfilmentAccordance.Insert(RowCondition.AssignmentCondition, ConditionExecuted);
				
				If Not ConditionExecuted Then
					AllConditionsFulfilled = False;
				EndIf;
				
			EndDo;
			
			// Discount amount
			If TreeRow.DataTable.Count() = 0 Then
				DiscountAmount = 0;
			Else
				FoundString = TreeRow.DataTable.Find(ProductsRow[CurAttributeConnectionKey], "ConnectionKey");
				If FoundString <> Undefined Then
					DiscountAmount = FoundString.Amount;
				Else
					DiscountAmount = 0;
				EndIf;
			EndIf;
			
			If AllConditionsFulfilled Then
				If DocumentObject.DiscountsMarkups.FindRows(New Structure("ConnectionKey, DiscountMarkup", ProductsRow[CurAttributeConnectionKey], TreeRow.DiscountMarkup)).Count() = 0 Then
					// Not valid for shared use.
					TextColor = "Gray";
					Strikeout = "Strikeout";
				Else
					// Present in document. Conditions are fullfilled.
					TextColor = "";
					Strikeout = "";
				EndIf;
			Else
				// Conditions are not fulfilled.
				TextColor = "Red";
				Strikeout = "Strikeout";
			EndIf;
			
			If ProductsCharacteristicsUsage Then
				AreaDiscount                         = Template.GetArea("DiscountCharacteristicsPresent"+Strikeout+TextColor+"|ProductsAndCharacteristics");
				AreaDiscountAmountAndCompleted          = Template.GetArea("DiscountCharacteristicsPresent"+Strikeout+TextColor+"|AmountAndCompleted");
			Else
				AreaDiscount                         = Template.GetArea("Discount"+Strikeout+TextColor+"|Products");
				AreaDiscountAmountAndCompleted          = Template.GetArea("Discount"+Strikeout+TextColor+"|AmountAndCompleted");
			EndIf;
			
			AreaDiscount.Parameters.DiscountMarkup = TreeRow.DiscountMarkup;
			SpreadsheetDocument.Put(AreaDiscount);
			
			AreaDiscountAmountAndCompleted.Parameters.Amount = DiscountAmount;
			SpreadsheetDocument.Join(AreaDiscountAmountAndCompleted);
			
			SpreadsheetDocument.StartRowGroup("Discount", True);
			
			// Discount conditions, continuation
			For Each RowCondition In TreeRow.ConditionsParameters.TableConditions Do
				
				If ConditionsFulfilmentAccordance.Get(RowCondition.AssignmentCondition) Then
					// The condition is fullfilled.
					Strikeout = "";
				Else
					// Condition is not completed.
					Strikeout = "Strikeout";
				EndIf;
				
				If ProductsCharacteristicsUsage Then
					AreaCondition                        = Template.GetArea("ConditionCharacteristicsPresent"+Strikeout+TextColor+"|ProductsAndCharacteristics");
					AreaConditionAmountAndCompleted         = Template.GetArea("ConditionCharacteristicsPresent"+Strikeout+TextColor+"|AmountAndCompleted");
				Else
					AreaCondition                        = Template.GetArea("Condition"+Strikeout+TextColor+"|Products");
					AreaConditionAmountAndCompleted         = Template.GetArea("Condition"+Strikeout+TextColor+"|AmountAndCompleted");
				EndIf;
				
				AreaCondition.Parameters.Condition = RowCondition.AssignmentCondition;
				SpreadsheetDocument.Put(AreaCondition);
				
				SpreadsheetDocument.Join(AreaConditionAmountAndCompleted);
				
			EndDo;
			
			SpreadsheetDocument.EndRowGroup(); // Discount.
			
		EndDo;
		
		SpreadsheetDocument.EndRowGroup(); // Products.
		
	EndDo;
	
	// Total
	SpreadsheetDocument.Put(AreaTotalProducts);
	If ProductsCharacteristicsUsage Then
		SpreadsheetDocument.Join(AreaTotalCharacteristic);
	EndIf;
	AreaTotalAmountAndCompleted.Parameters.Amount = DocumentObject[TSName].Total("AutomaticDiscountAmount");
	SpreadsheetDocument.Join(AreaTotalAmountAndCompleted);
	
	SpreadsheetDocument.Put(AreaLegend);
	
EndProcedure

#EndRegion
