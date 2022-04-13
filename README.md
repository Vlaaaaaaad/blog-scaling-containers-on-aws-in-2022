# Scaling containers on AWS - 2022

This repo contains the Terraform files used for my [Scaling containers in AWS blog post](https://vladionescu.me/posts/scaling-containers-on-aws-in-2022/).

**This is not pretty or correct code! Do not take inspiration from here!**

![Hand-drawn-style graph showing how long it takes to scale from 0 to 3500 containers: Lambda instantly spikes to 3000 and then jumps to 3500, ECS on Fargate starts scaling after 30 seconds and reaches close to 3500 around the four and a half minute mark, EKS on Fargate starts scaling after about a minute and reaches close to 3500 around the eight and a half minute mark, EKS on EC2 starts scaling after two and a half minutes and reaches 3500 around the six and a half minute mark, and ECS on EC2 starts scaling after two and a half minutes and reaches 3500 around the ten minute mark](./overview.png)
