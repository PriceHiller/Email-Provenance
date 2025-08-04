#let gold = rgb("#ffc500")
#set text(font: "Calibri", size: 12.5pt)
#show link: set text(blue)
#show cite: set text(blue)
#let gradient_fill = (
  color.hsl(230deg, 60%, 20%),
  color.hsl(225deg, 60%, 15%),
  color.hsl(220deg, 60%, 15%),
  color.hsl(220deg, 60%, 15%),
  color.hsl(220deg, 60%, 15%),
  color.hsl(220deg, 60%, 15%),
  color.hsl(210deg, 60%, 15%),
  color.hsl(210deg, 80%, 20%),
)
#let imageonside(
  lefttext,
  rightimage,
  bottomtext: none,
  marginleft: 0em,
  margintop: 0.5em,
) = {
  set par(justify: true)
  grid(
    columns: 2,
    column-gutter: 1em,
    lefttext, rightimage,
  )
  set par(justify: false)
  block(inset: (left: marginleft, top: -margintop), bottomtext)
}

#show heading: header => {
  let heading_level = str(header.level)
  let heading_map = (
    "1": (bgfill: gold, textfill: black),
    "2": (bgfill: rgb("#00265E"), textfill: white),
    "3": (bgfill: red.darken(50%), textfill: white),
  )
  let (bgfill, textfill) = heading_map.at(str(heading_level))
  block(inset: (x: 8pt, y: 8pt), radius: 30%, fill: bgfill, text(
    font: "Roboto",
    fill: textfill,
    tracking: .1pt,
    weight: "black",
  )[#header.body])
}

#let accent_font = "IBM Plex Sans"
#let title = [AWS & Terraform: Proving Provenance of Emails via DKIM]
#set page(
  "us-letter",
  margin: (x: .5in, top: 1in, bottom: .5in),
  header: context if here().page() > 1 {
    align(center + horizon, box(width: page.width + 4em, height: 100%, fill: gradient.linear(..gradient_fill), [
      #place(left + horizon, dx: +page.margin.left + 10pt)[
        #text(size: 1.1em, fill: gold, font: accent_font, weight: "black")[Cloud Computing | Group 10],
        #text(size: 1.1em, fill: white)[#title],
      ]
      #let icon_size = 45%
      #place(right + horizon, dx: -page.margin.left, box(
        baseline: icon_size,
      ))
    ]))
  },
  footer: context if here().page() > 1 {
    text(size: 0.8em, fill: color.luma(35%), [
      #v(.75em)
      Cloud Computing Project Proposal | CS 4843-01T | Group 10
      #h(1fr)
      #{
        here().page()
      }
    ])
    align(center + bottom, block(width: page.width + 10pt, height: 20%, fill: gradient.linear(..gradient_fill)))
  },
)

// COVER PAGE

#set page(background: context if here().page() == 1 {
  box(
    fill: gradient.linear(angle: 60deg, ..gradient_fill),
    width: 100%,
    height: 100%,
  )

  place(top + center, rect(width: 100%, height: 100%, fill: tiling(size: (18pt, 18pt), place(dy: 3pt, dx: 1pt, circle(
    radius: 3.5pt,
    fill: blue.darken(65%),
  )))))

  let globe = read("./assets/globe.svg").replace("#000000", blue.darken(40%).to-hex())
  place(bottom + right, dy: 70pt, dx: 120pt, rotate(-20deg, image(
    bytes(globe),
    height: 600pt,
  )))


  let darken_amount = 15%
  place(top + right, stack(dir: btt, ..{
    let rect_height = 30pt
    (
      rect(width: 50pt, height: rect_height, fill: red.darken(
        darken_amount + 10%,
      )),
      rect(width: 75pt, height: rect_height, fill: gold.darken(darken_amount)),
      rect(width: 100pt, height: rect_height, fill: blue.darken(darken_amount)),
    )
  }))

  place(horizon + left, rect(
    fill: blue.darken(darken_amount),
    height: 100%,
    width: 8pt,
  ))
})

#context {
  let icon_size = 36pt
  place(left + top, align(horizon, grid(
    columns: 1,
    row-gutter: 10pt,
    text(
      size: 1.3em,
      font: accent_font,
      fill: gold,
      weight: "black",
    )[
      Price Hiller\
      Cody Ledbetter\
      Roman Rendon\
      Sean Nicosia\
    ],
    text(size: 1.15em, font: accent_font, fill: gold.darken(10%))[
      Project Group 10
    ],
  )))
  place(center + horizon, box(width: page.width / 1.08, text(
    font: "Roboto",
    size: 5em,
    fill: blue.lighten(75%),
    weight: "black",
  )[#title]))

  place(left + bottom, dy: +8%, text(
    size: .75em,
    fill: white,
    style: "italic",
  )[#title])
}

#pagebreak()

= Overview

The purpose of this project is to create a simple DKIM record tracker using Amazon Web Services (AWS) resources orchestrated through Terraform.

Tracking DKIM records is of increasing importance in modern business environments due to the prevalence of man-in-the-middle attacks in email. Proving the provenance of an email allows for an aggrieved party to show, beyond a reasonable doubt, a breach of a business partner's emails before a court. Maintaining historical DKIM records is tantamount to proving historical email provenance.

For instance, take business partners agreeing to a wire transfer in which an attacker has access to one of the partner's emails. The attacker could then send an email from the breached partner, appearing as them, with the attacker's bank info to fraudulently attain funds. If the partner lost their funds to the attacker, they would now have a cause of action to recover their lost funds from their business partner due to that partner's cybersecurity negligence.

= Goals

+ Understand the basics of various AWS resources such as (but not limited to):
  - Lambda
  - Route53
  - DynamoDB
  - EventBridge Scheduler
+ Learn to provision resources in a public cloud with Hashicorp Terraform
+ Understand how to execute idempotent, coordinated DNS record lookups from AWS
+ Demonstrate knowledge of modern CI/CD practices, leveraging pipelines to test, build, and deploy services from Github using Github Actions
+ Understand secure secret management & lifecycles in AWS
  - AWS Key Management Service
  - AWS Identity Access Management

= Testbed & Software Tools

+ AWS
  - Lambda
  - Route53
  - DynamoDB
  - EventBridge Scheduler
  - AWS Key Management Service
  - AWS Identity Access Management
+ Python 3.13
+ Terraform
+ Github & Github Actions
