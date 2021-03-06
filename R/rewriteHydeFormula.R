#' @name rewriteHydeFormula
#' @importFrom dplyr group_by_
#' @importFrom dplyr summarise
#' @importFrom stats as.formula
#' @importFrom stringr str_split_fixed
#' @importFrom utils tail
#' 
#' @title Rewrite HydeNetwork Graph Model Formula
#' @description This is a convenience function used to assist in the updating 
#'   of \code{HydeNetwork} network objects.  It makes it possible to add and 
#'   subtract individual parent relationships without deleting an entire node.   
#'   It's still a work in progress.
#'   
#' @param old_form The current formula in a \code{HydeNetwork} object.
#' @param new_form The formula specifications to be added
#' 
#' @details To allow changes to be made on the node-parent level, the formulae
#'   are broken down into a vector of component where each element identifies
#'   a unique parent-child relationship.  So if a node has representation
#'   \code{nodeA | nodeB*nodeC}, it will be broken down to 
#'   \code{nodeA | nodeB + nodeA | nodeC}.  
#'   
#'   After decomposing the formulae, any instances of a component in 
#'   \code{form1} that are subtracted in \code{form2} are removed.
#'   
#'   Next, all added components in \code{form2} that do not already exist in
#'   \code{form1} are added.
#'   
#'   Lastly, the parents of each node are combined and the specification
#'   of the network is written.
#'   
#' @author Jarrod Dalton and Benjamin Nutter

rewriteHydeFormula <- function(old_form, new_form){
  #* Subroutine for decomposing formulae
  reduce_formula <- function(f)
  {
    f <- gsub(pattern = "[+]", 
              replacement = "+_+", 
              x = utils::tail(as.character(f), 1))
    f <- gsub(pattern = "[-]", 
              replacement = "-_-", 
              x = f)
    f <- unlist(strsplit(x = f, 
                         split = "[+]_"))
    f <- unlist(strsplit(x = f, 
                         split = "[-]_"))
    f <- f[f != ". "]
    f <- strsplit(x = f, 
                  split = "[|]")
    f <- sapply(X = f, 
                FUN = 
                  function(x)
                  {
                    if (length(x) == 1) 
                    {
                      x 
                    }
                    else 
                    {
                      paste(x[1], unlist(strsplit(x = x[-1], 
                                                  split = "[*]")), 
                            sep="|")
                    }
                  }
              )
    f <- unlist(f)
    f <- sub(pattern = "\\s+$", 
             replacement = "", 
             x = f, 
             perl = TRUE) ## Perl-style white space
    return(f)
  }

  #* Subroutine for merging formulae
  combine_form <- function(f1, f2){
    f1 <- sub(pattern = "[+] ", 
              replacement = "", 
              x = f1)
    f2_match <- sub(pattern = "([+]|[-]) ", 
                    replacement = "", 
                    x = f2)
    
    #* Remove complete nodes
    for (i in seq_along(f2))
    {
      if (!grepl(pattern = "[|]", 
                 x = f2_match[i]))
      {
        f1 <- gsub(pattern = f2_match[i], 
                   replacement = "", 
                   x = f1)
      }
    }
 
    #* Remove subtracted relations
    for(i in seq_along(f1))
    {
      f1[i] <- 
        if (f1[i] %in% f2_match)
        {
          if (substr(f2[f2_match %in% f1[i]], 1, 1) == "-") 
          {
            NA 
          }
          else 
          {
            f1[i] 
          }
        } 
        else 
        {
          f1[i]
        }
    }
  
    #* Remove subtractions
    f2 <- f2[!substr(f2, 1, 1) == "-"]
    f2 <- sub(pattern = "[+]", 
              replacement = "", 
              x = f2)
    f2 <- f2[!f2 %in% f1]
   
    f <- c(f1, f2)
    f[!is.na(f)]
  }
  
  #* Decompose and merge formulae
  f <- combine_form(reduce_formula(old_form),
                    reduce_formula(new_form))

  #* Combine parents into one vector
  Form <- as.data.frame(stringr::str_split_fixed(string = f, 
                                                 pattern = "[|]", 
                                                 n = 2),
                        stringsAsFactors=FALSE)
  names(Form) <- c("node", "parent")
  parent <- NULL
  
  Form <- Form[!Form$node %in% " ", ]
  
  Form <- Form %>%
    dplyr::group_by(node) %>%
    dplyr::summarise(parent = paste(parent[!parent %in% c(" ")], collapse = "*"))
  
  #* Paste together the complete formula
  Form <- apply(X = Form, 
                MARGIN = 1, 
                FUN = function(x) if (x[2] != "") paste(x, collapse="|") else x[1])

  Form <- paste0("~ ", paste(Form, collapse=" + "))
  
  stats::as.formula(Form)
}

utils::globalVariables("node")
