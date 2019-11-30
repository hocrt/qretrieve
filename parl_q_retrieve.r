#script that gets random queries for a given period from the hellenic parliament server
require(XML)
require(htmltab)
require(RCurl)
require(stringr)

session<-{} #object contains data specific to the session period

#https://gist.github.com/drammock/9e152746a9f99d56a6ec
#needed to save tables to file in UTF-8
save.utf8 <- function(df, file, sep=",", quote=FALSE) {
  con <- file(file, open="wb", encoding="UTF-8")
  mat <- as.matrix(df)
  header <- colnames(df)
  writeLines(paste(header, collapse=sep), con, useBytes=TRUE)
  invisible(apply(mat, 1, function(i) {
    if(quote) line <- sapply(i, function(j) paste0("\"", j, "\"", collapse=""))
    else      line <- i
    writeLines(paste(line, collapse=sep), con, useBytes=TRUE)
  }))
  close(con)
}

#reads the 1st row of a file - needed for the table columns of the period and queries (stored in fileout1.txt,fileout2.txt)
readfileout <- function(filename){ #read txt file
  con=file(filename,"r") 
  header=readLines(con)
  close(con)
  return(header)
}

currentDir<-paste(getwd(),"/out",sep="")
setwd(currentDir) #set directory

# Questions                                 - type=63c1d403-0d19-409f-bb0d-055e01e1487c
# and for the session 05.02.2015-28.08.2015 - SessionPeriod=ef3c0f44-85cc-4dad-be0c-a43300bca218

# ddSessionPeriod
# ddtype
# ddPoliticalParties
# ddMps


#create 4 files/tables with query types,session periods,political parties and parliament members
writeQueryTables <- function(){
  #the queries look like this
  url<- "https://www.hellenicparliament.gr/Koinovouleftikos-Elenchos/Mesa-Koinovouleutikou-Elegxou?subject=&protocol=&ministry=&datefrom=&dateto=&type=63c1d403-0d19-409f-bb0d-055e01e1487c&SessionPeriod=ef3c0f44-85cc-4dad-be0c-a43300bca218&partyId=&mpId=&pageNo=&SortBy=ake&SortDirection=asc"
  
  t1 <- getURL(url,.opts = list(ssl.verifypeer = FALSE) )
  t1 <- htmlParse(t1)
  
  options <- getNodeSet(xmlRoot(t1),"//select[@id='ddtype']/option")
  ids_ddtype <- sapply(options, xmlGetAttr, "value")
  ddtype <- sapply(options, xmlValue)
  
  options <- getNodeSet(xmlRoot(t1),"//select[@id='ddSessionPeriod']/option")
  ids_sesper <- sapply(options, xmlGetAttr, "value")
  sesper <- sapply(options, xmlValue)
  
  options <- getNodeSet(xmlRoot(t1),"//select[@id='ddPoliticalParties']/option")
  ids_polpar <- sapply(options, xmlGetAttr, "value")
  polpar <- sapply(options, xmlValue)
  
  options <- getNodeSet(xmlRoot(t1),"//select[@id='ddMps']/option")
  ids_mps <- sapply(options, xmlGetAttr, "value")
  mps <- sapply(options, xmlValue)
  
#now let's write those to files in UTF-8
  df1<- data.frame(ID=ids_ddtype, Name=ddtype)
  save.utf8(df1,'parl_ddtype.csv')
  df2<- data.frame(ID=ids_sesper, Name=sesper)
  save.utf8(df2,'parl_sesper.csv')
  df3<- data.frame(ID=ids_polpar, Name=polpar)
  save.utf8(df3,'parl_polpar.csv')
  df4<- data.frame(ID=ids_mps, Name=mps)
  save.utf8(df4,'parl_mps.csv')
  
  session$type<<-ids_ddtype
  session$period<<-ids_sesper
}

#gets the url for a page of queries for a given period(sq,dt)
getFullUrl <- function(sp,dt,page){
  q0<-"/Koinovouleftikos-Elenchos/Mesa-Koinovouleutikou-Elegxou?"
  q1<-"subject="
  q2<-"&protocol="
  #q3<-"&type=63c1d403-0d19-409f-bb0d-055e01e1487c"
  q3<-paste("&type=",session$type[dt],sep="")
  #q4<-"&SessionPeriod=ef3c0f44-85cc-4dad-be0c-a43300bca218"
  q4<-paste("&SessionPeriod=",session$period[sp],sep="")
  q5<-"&partyId="
  q6<-"&mpId="
  q7<-"&ministry="
  q8<-"&datefrom="
  q9<-"&dateto="
  q11<-"&SortBy=ake&SortDirection=asc"
  q10<-ifelse(page>0,paste("&pageNo=",page,sep=""),paste("&pageNo="))
  url0<- "https://www.hellenicparliament.gr"
  url<- paste(url0,q0,q1,q2,q3,q4,q5,q6,q7,q8,q9,q10,q11,sep="")
  return(url)
}

#returns the period as a vector of sp,dt,qtotnum
selectPeriodsDataTypes <- function(sp=1,dt=2){
  t51<-readfileout("../fileout1.txt") #file contains the header with 12 fields - one entry per line
  url<-getFullUrl(sp,dt,0)
  #now let's read the 1st page
  
  t1<- getURL(url,.opts = list(ssl.verifypeer = FALSE) )
  t1<- htmlParse(t1)
  
  #we'll use htmltab to extract the table, we're lucky there's only one table in the page, so we don't specify location
  t2<- tryCatch(htmltab(doc = t1,which=1,rm_nodata_cols=F),
                error = function(e)e,warning = function(w)w
  )
  cname<- colnames(t2)[1] #get header
  #pagenum has total num of result pages - we'll use them in q10<-"pageNo="
  cnums<-as.numeric(unique(unlist(regmatches(cname, gregexpr("[0-9]+", cname))))) #extract total num, cur page, total page num
  pagenum<- cnums[3]
  qtotnum<- cnums[1]

  print(paste("total results:",qtotnum,"| number of pages:",pagenum))
  session$sp<<-sp
  session$dt<<-dt
  session$qtotnum<<-qtotnum
}
# create a sublist of the total result
# num selects how many links to get - up to total results
# num can be single value or a range
# prc overrides num and gets percentage of links
createRandomList <- function(num=500,prc=0) {
  qtotnum<-session$qtotnum
  if(exists("qtotnum")) {
    if(length(num)==2){
      num1<-num[1]
      num2<-num[2]
      if(num1>qtotnum){
        num1<-qtotnum
      }
      if(num2>qtotnum){
        num2<-qtotnum
      }
      if(num1<1){
        num1<-1
      }
      if(num2<1){
        num2<-1
      }
      res<-seq(num1,num2)
    }
    else if(length(num)==1) { 
      if(num>qtotnum) {
          num<-qtotnum
          res<-sample(seq(1,qtotnum),num)
        } else {
          res<-sample(seq(1,qtotnum),num)
        } 
      if(prc>0) {
        num<-round(qtotnum*prc/100)
        if(num>qtotnum) {
          num<-qtotnum
        } 
        res<-sample(seq(1,qtotnum),num)
      }
      print(res)
    }
    return(res)
  }
  else {
    return(c(NULL))
  }
}

# num=0 -> download whole page number=page
# num>0 -> download from page number=page item=num
pageScrape <-function(page, num) {
    url0<- "https://www.hellenicparliament.gr"
    t51<-readfileout("../fileout1.txt") #file contains the header with 12 fields - one entry per line
    url<-getFullUrl(session$sp,session$dt,page)
    t1<- getURL(url,.opts = list(ssl.verifypeer = FALSE) )
    t1<- htmlParse(t1)
    t2<- htmltab(doc = t1,rm_nodata_cols = F,which=1)
    #print(paste("t2",nrow(a3),ncol(a3)))
    t2<- t2[,1:4]
    t2<-t2[1:nrow(t2)-1,] #remove last row
    
    #now get the links from the table
    g1<-as.character(getNodeSet(xmlRoot(t1), "//a/@href")) #filter xml for href
    l1=c(NULL) #using for loop slows things down - sapply would be faster
    for(j in 1:length(g1)){  #the links should have ?pcm_id=
      l1[j]=length(unlist(strsplit(g1[j],"[?=]"))) # result should be 3
    }
    
    g2<-g1[which(l1==3)]  #these should be the links
    g2<- paste(url0,g2,sep="")
    #append links as last column
    g3<-cbind(t2,data.frame(g2))  
    
    #now get the fields after the link
    a1=c(NULL)
    for(k in 1:length(g2)){
      #k=3
      t3<-getURL(g3[k,5],.opts = list(ssl.verifypeer = FALSE) )
      t4<- htmlParse(t3)
      t5 <- xpathSApply(t4, "//dt", xmlValue) # titles
      t6 <- xpathSApply(t4, "//dd", xmlValue) # values
      t6<-gsub("\\r\\n","-",t6)   # if length=13 discard 8th field : Information (empty)
      t6<-gsub("\\t","",t6)
      
      #write the header to fileout2 to compare to t51 - because of unicode encoding in R it doesn't work correctly otherwise
      write.table(iconv(t5,from="",to=""),file="../fileout2.txt",row.names = F,quote = F, col.names = F)
      t52=readfileout("../fileout2.txt")
      
      t53<-match(t52,t51)  #position of the field or NA if not available
      t54<-match(seq(12),t53)
      t55<-c(NULL) 
      for (j in 1:12){ #copy correct element or empty string
        t55<-c(t55,ifelse(is.na(t54[j]),"",t6[t54[j]]))
      }
      t6<-t55 # copy to initial vector
      
      t7<-as.character(getNodeSet(xmlRoot(t4), "//a/@href")) #1st is question - rest are answer files
      t8<-substr(t7,str_length(t7)-2,str_length(t7))
      t9<-which(t8=="pdf") #only keep links ending in "pdf"
      t10<-paste(url0,t7[t9],sep="")
      if(length(t10)>0){ #question file
        t6[11]<-t10[1]
      }
      if(length(t10)>1){ #answer files
        t6[12]<-toString(t10[-1])
      }
      
      t61<-unlist(str_split(unlist(str_split(t6[11],"/"))[6],".pdf"))[1] #just the question link
      t61<-ifelse(is.na(t61),"",t61) 
      t6<-c(t6,t61) #add link as 13th field
      
      #print(length(t6))
      
      a1<-iconv(c(a1,t6),from="",to="") #necessary character conversion
    }
    
    a2<-matrix(a1,nrow = length(t6))  #convert vector to matrix
    a3<-cbind(g3,t(a2))  #append the fields at the end of the table
    
    #change column titles - use only english names because greek characters cannot be saved reliably in r script despite utf-8 encoding
    colnames(a3)<-c("Protocol Number","Date","Type","Subject","Link","Number","Type","Session/Period","Subject","Party","Date","Date Last Modified","Submitter","Ministries","Ministers","Question File","Answer Files","link serialNr")
    
    print(paste("page:",page)) #print page num
    if(num==0) {
      return(a3)
    }
    else {
      return(a3[num,])
    }
}

#period is returned by selectPeriodsDataTypes
#queries is a list of query numbers between 1..qtotnum
getQueries <- function(queries) {
  result<-c(NULL)
  for (query in queries) {
    tableNumber<-floor(query/10)
    queryNumber<-query%%10
    res<-pageScrape(tableNumber,queryNumber)
    #append to previous result
    result<- rbind(result,res)
  }
  writeResults(result)
}

#write table to file
writeResults <- function(res) {
  write.table(res,"result.csv",sep="#",col.names = T,row.names = F, quote=F) #set separator to # because ",; are already used
}

writeQueryTables() # write data table to files
selectPeriodsDataTypes() # select period
getQueries(createRandomList(1)) # get random results

