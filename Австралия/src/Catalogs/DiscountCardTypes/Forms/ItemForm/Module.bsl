#Region CommonProceduresAndFunctions

&AtClient
// Returns the text presentation of an interval.
//
Function GetIntervalView(TabularSection, CurrentRow)
	
	MaxLowerLimit = Undefined;
	NextString = Undefined;
	For Each TSRow In TabularSection Do
		If (MaxLowerLimit = Undefined Or MaxLowerLimit >= TSRow.LowerBound)
		   AND CurrentRow.LowerBound <= TSRow.LowerBound
		   AND TSRow <> CurrentRow Then
			NextString = TSRow;
			MaxLowerLimit = TSRow.LowerBound;
		EndIf;
	EndDo;
	
	If NextString = Undefined Then
		IntervalView = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'From %1 %2'; ru = 'От %1 %2';pl = 'Od %1 %2';es_ES = 'Desde %1 %2';es_CO = 'Desde %1 %2';tr = '%1 %2 itibaren';it = 'Da %1 %2';de = 'Von %1 %2'"),
			TrimAll(CurrentRow.LowerBound), PresentationCurrency);
	ElsIf CurrentRow.LowerBound = NextString.LowerBound Then
		IntervalView = NStr("en = 'ERROR: such lower limit already exists.'; ru = 'ОШИБКА: такая нижняя граница уже есть.';pl = 'BŁĄD: taki dolny limit już istnieje.';es_ES = 'ERROR: un límite tan bajo ya existe.';es_CO = 'ERROR: un límite tan bajo ya existe.';tr = 'HATA: böyle bir alt sınır zaten var.';it = 'ERRORE: questo limite minimo già esiste.';de = 'FEHLER: Diese Untergrenze ist bereits vorhanden.'");
	Else
		IntervalView = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'From %1 to %2 %3'; ru = 'От %1 до %2 %3';pl = 'Od %1 do %2 %3';es_ES = 'Desde %1 hasta %2 %3';es_CO = 'Desde %1 hasta %2 %3';tr = '%1 itibaren %2 %3 kadar';it = 'Dal %1 al %2 %3';de = 'Von %1 bis %2 %3'"),
			TrimAll(CurrentRow.LowerBound), TrimAll(NextString.LowerBound), PresentationCurrency);
	EndIf;
	
	Return IntervalView;
	
EndFunction

// The procedure updates a value in the column "IntervalView" of spreadsheet part "AccumulativeDiscountsThresholds".
//
&AtClient
Procedure UpdateAllRowsPresentation()

	For Each CurRow In Object.ProgressiveDiscountLimits Do
		CurRow.IntervalView = GetIntervalView(Object.ProgressiveDiscountLimits, CurRow);
	EndDo;

EndProcedure

#EndRegion

#Region ProceduresFormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Object.DiscountKindForDiscountCards) Then
		Object.DiscountKindForDiscountCards = PredefinedValue("Enum.DiscountTypeForDiscountCards.FixedDiscount");
	EndIf;
	If Not ValueIsFilled(Object.CardType) Then
		Object.CardType = Enums.CardsTypes.Barcode;
	EndIf;	
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	ReadOnly = Not AllowedEditDocumentPrices;
	PresentationCurrency = DriveReUse.GetFunctionalCurrency();
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	VisibleManagementAtServer();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	VisibleManagementAtServer();
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	UpdateAllRowsPresentation();
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	UpdateAllRowsPresentation();
	
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

#Region ProceduresElementFormEventsHandlers

// Procedure - event handler OnChange item CardType.
//
&AtClient
Procedure CardTypeOnChange(Item)
	
	Items.DiscountCardTemplate.Visible = (Object.CardType <> PredefinedValue("Enum.CardsTypes.Barcode"));
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

// Procedure - event handler OnChange item DiscountKindForDiscountCards.
//
&AtClient
Procedure DiscountKindForDiscountCardsOnChange(Item)
	
	VisibleManagementAtServer();
	
EndProcedure

// Procedure - event  handler OnChange item PeriodKind.
//
&AtClient
Procedure PeriodKindOnChange(Item)
	
	PeriodKindOnChangeAtServer();
	
EndProcedure

// Procedure - events handler OnChange item PeriodKind (server part).
//
&AtServer
Procedure PeriodKindOnChangeAtServer()
	
	Items.Periodicity.Visible = (Object.PeriodKind <> PredefinedValue("Enum.PeriodTypeForCumulativeDiscounts.EntirePeriod"));
	If Not ValueIsFilled(Object.Periodicity) AND Items.Periodicity.Visible Then
		Object.Periodicity = PredefinedValue("Enum.Periodicity.Year");
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region ProceduresSpreadsheetPartEventsHandlers

// Procedure - events handler "OnEditingFinish" rows in the SP "AccumulativeDiscountsThresholds".
//
&AtClient
Procedure ProgressiveDiscountLimitOnEditEnd(Item, NewRow, CancelEdit)
	
	// After inputing the string, sort SP in ascending order until the lower limit.
	Object.ProgressiveDiscountLimits.Sort("LowerBound");
	UpdateAllRowsPresentation();
	
EndProcedure

// Procedure - events handler "OnChange" for column "LowerLimit" rows in SP "AccumulativeDiscountsThresholds".
//
&AtClient
Procedure ProgressiveDiscountLimitsLowerBoundOnChange(Item)
	
	CurRowItem = Items.ProgressiveDiscountLimits.CurrentData;
	CurRowItem.IntervalView = GetIntervalView(Object.ProgressiveDiscountLimits, CurRowItem);
	
EndProcedure

// Procedure - events handler "AfterDeletion" SP "AccumulativeDiscountsThresholds".
//
&AtClient
Procedure ProgressiveDiscountLimitsAfterDeleteRow(Item)
	
	UpdateAllRowsPresentation();
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForFormAppearanceManagement

// The procedure is intended for management of form items visible depending on the kind and type of discount card.
&AtServer
Procedure VisibleManagementAtServer()

	If Object.DiscountKindForDiscountCards = PredefinedValue("Enum.DiscountTypeForDiscountCards.ProgressiveDiscount") AND
		Object.PeriodKind.IsEmpty() Then
		Object.PeriodKind = PredefinedValue("Enum.PeriodTypeForCumulativeDiscounts.EntirePeriod");
	EndIf;
	
	Items.Discount.Visible = (Object.DiscountKindForDiscountCards = PredefinedValue("Enum.DiscountTypeForDiscountCards.FixedDiscount"));
	TheseAreAccumulativeDiscounts = (Object.DiscountKindForDiscountCards = PredefinedValue("Enum.DiscountTypeForDiscountCards.ProgressiveDiscount"));
	Items.ProgressiveDiscountLimits.Visible = TheseAreAccumulativeDiscounts;
	Items.PeriodKind.Visible = TheseAreAccumulativeDiscounts;
	Items.Periodicity.Visible = (Object.PeriodKind <> PredefinedValue("Enum.PeriodTypeForCumulativeDiscounts.EntirePeriod")) AND TheseAreAccumulativeDiscounts;
	Items.DiscountCardTemplate.Visible = (Object.CardType <> PredefinedValue("Enum.CardsTypes.Barcode"));
	
EndProcedure

#EndRegion