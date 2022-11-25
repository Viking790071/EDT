
#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Structure = New Structure;
	Structure.Insert("Day", Enums.Periodicity.Day);
	Structure.Insert("Week", Enums.Periodicity.Week);
	Structure.Insert("Month", Enums.Periodicity.Month);
	Structure.Insert("Quarter", Enums.Periodicity.Quarter);
	Structure.Insert("HalfYear", Enums.Periodicity.HalfYear);
	Structure.Insert("Year", Enums.Periodicity.Year);
	
	StructurePeriodicity = Structure;		
	
	If Object.Predefined Then
		
		Items.Periodicity.Enabled = False;
		Items.StartDate.Enabled = False;
		Items.StartDate.AutoMarkIncomplete = False;
		Items.EndDate.Enabled = False;
		Items.EndDate.AutoMarkIncomplete = False;
		
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
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

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
// Procedure - event handler OnChange of field StartDate.
//
Procedure BeginDateOnChange(Item)
			
	If ValueIsFilled(Object.Periodicity)
		AND ValueIsFilled(Object.StartDate) Then
		
		If Object.Periodicity = StructurePeriodicity.Week Then	
			
			Object.StartDate = BegOfWeek(Object.StartDate);
						
		ElsIf Object.Periodicity = StructurePeriodicity.Month Then	
			
			Object.StartDate = BegOfMonth(Object.StartDate);
						
		ElsIf Object.Periodicity = StructurePeriodicity.Quarter Then	
			
			Object.StartDate = BegOfQuarter(Object.StartDate);
						
		ElsIf Object.Periodicity = StructurePeriodicity.HalfYear Then	
			
			MonthOfStartDate = Month(Object.StartDate);
			
			Object.StartDate = BegOfYear(Object.StartDate);

			If MonthOfStartDate > 6 Then
				
				Object.StartDate = AddMonth(Object.StartDate, 6);
				
			EndIf;	
						 
		ElsIf Object.Periodicity = StructurePeriodicity.Year Then
			
			Object.StartDate = BegOfYear(Object.StartDate);
						
		EndIf;	
			
	EndIf;	
	
	If Object.StartDate > Object.EndDate 
		AND ValueIsFilled(Object.EndDate) Then
				
		Message = New UserMessage;
		Message.Text = NStr("en = 'The Start date field value is greater than the End date field value.'; ru = 'Значение поля ""Дата начала"" больше значения поля ""Дата окончания""';pl = 'Wartość pola Data rozpoczęcia jest większa niż wartość pola Data zakończenia.';es_ES = 'El valor del campo de la fecha Inicial es mayor al valor del campo de la fecha Final.';es_CO = 'El valor del campo de la fecha Inicial es mayor al valor del campo de la fecha Final.';tr = 'Başlangıç tarihi alanındaki değer Bitiş tarihi alanındaki değerden ileri.';it = 'Il valore del campo Data di inizio è maggiore del valore del campo Data di fine.';de = 'Der Feldwert Startdatum ist größer als der Feldwert Enddatum.'");
		Message.Field = "Object.StartDate";
		Message.Message();
				
	EndIf;	
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of field EndDate.
//
Procedure EndingDateOnChange(Item)
			
	If ValueIsFilled(Object.Periodicity)
		AND ValueIsFilled(Object.EndDate) Then
		
		If Object.Periodicity = StructurePeriodicity.Week Then	
			
			Object.EndDate = EndOfWeek(Object.EndDate);
			
		ElsIf Object.Periodicity = StructurePeriodicity.Month Then	
			
			Object.EndDate = EndOfMonth(Object.EndDate);
			
		ElsIf Object.Periodicity = StructurePeriodicity.Quarter Then	
			
			Object.EndDate = EndOfQuarter(Object.EndDate);
			
		ElsIf Object.Periodicity = StructurePeriodicity.HalfYear Then	
			
			MonthEndDates = Month(Object.EndDate);
			
			Object.EndDate = EndOfYear(Object.EndDate);

			If MonthEndDates < 7 Then
				
				Object.EndDate = AddMonth(Object.EndDate, - 6);
				
			EndIf;	
			 
		ElsIf Object.Periodicity = StructurePeriodicity.Year Then
			
			Object.EndDate = EndOfYear(Object.EndDate);
			
		EndIf;	
			
	EndIf;
	
	If Object.StartDate > Object.EndDate 
		AND ValueIsFilled(Object.StartDate) Then
				
		Message = New UserMessage;
		Message.Text = NStr("en = 'The End date field value is less than the Start date field value.'; ru = 'Значение поля ""Дата окончания"" меньше значения поля ""Дата начала""';pl = 'Wartość pola Data zakończenia jest mniejsza niż wartość pola Data rozpoczęcia.';es_ES = 'El valor del campo de la fecha Final es menor al valor del campo de la fecha Inicial.';es_CO = 'El valor del campo de la fecha Final es menor al valor del campo de la fecha Inicial.';tr = 'Bitiş tarihi alanındaki değer Başlangıç tarihi alanındaki değerden geri.';it = 'Il valore del campo Data di fine è inferiore al valore del campo Data di inizio.';de = 'Der Feldwert Enddatum ist kleiner als der Feldwert Startdatum.'");
		Message.Field = "Object.EndDate";
		Message.Message();
						
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of field Periodicity.
//
Procedure PeriodicityOnChange(Item)
			
	If ValueIsFilled(Object.StartDate)
		AND ValueIsFilled(Object.EndDate) Then
		
		If Object.Periodicity = StructurePeriodicity.Week Then	
			
			Object.StartDate = BegOfWeek(Object.StartDate);
			Object.EndDate = EndOfWeek(Object.EndDate);
			
		ElsIf Object.Periodicity = StructurePeriodicity.Month Then	
			
			Object.StartDate = BegOfMonth(Object.StartDate);
			Object.EndDate = EndOfMonth(Object.EndDate);
			
		ElsIf Object.Periodicity = StructurePeriodicity.Quarter Then	
			
			Object.StartDate = BegOfQuarter(Object.StartDate);
			Object.EndDate = EndOfQuarter(Object.EndDate);
			
		ElsIf Object.Periodicity = StructurePeriodicity.HalfYear Then	
			
			MonthOfStartDate = Month(Object.StartDate);
			
			Object.StartDate = BegOfYear(Object.StartDate);

			If MonthOfStartDate > 6 Then
				
				Object.StartDate = AddMonth(Object.StartDate, 6);
				
			EndIf;	
				
			MonthEndDates = Month(Object.EndDate);
			
			Object.EndDate = EndOfYear(Object.EndDate);

			If MonthEndDates < 7 Then
				
				Object.EndDate = AddMonth(Object.EndDate, - 6);
				
			EndIf;	
			 
		ElsIf Object.Periodicity = StructurePeriodicity.Year Then
			
			Object.StartDate = BegOfYear(Object.StartDate);
			Object.EndDate = EndOfYear(Object.EndDate);
			
		EndIf;	
			
	EndIf;	
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion
